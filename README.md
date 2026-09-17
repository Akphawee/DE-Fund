# E-commerce Order Analytics Pipeline

> Status: In Progress — Day 22-23 / 28 (started 2026-08-07)

## Problem

Online stores get a constant stream of order, customer, and product data, but the raw data has problems: duplicate records, orphan orders (no matching customer), payment status that doesn't match order status. This makes revenue numbers unreliable and queries harder than they should be.

This project builds a pipeline that extracts the data, checks its quality, transforms it, and outputs a serving table the analytics team can query directly to answer business questions like "which customer segment spends the most per province" or "how does today's revenue compare to yesterday's."

## Architecture (grows as new topics are added)

```
Source (CSV/API) → raw/ → staging/ → serving/
                                          ↓
                              Orchestrated by Airflow (see below)
```

Full details (OLTP vs OLAP, why raw data is stored separately, file format choice) in [`docs/architecture.md`](docs/architecture.md)

Role of each tool (cron/script/SQL engine/warehouse) and why this starts with batch instead of streaming: [`docs/compute_notes.md`](docs/compute_notes.md)

## Project Structure

```
.
├── README.md
├── Dockerfile
├── requirements.txt
├── src/
│   ├── clean_order.py       # extract -> deduplicate -> validate -> load (idempotent, incremental)
│   ├── daily_summary.py     # aggregate orders_clean.csv -> daily serving table
│   ├── extract_api.py       # API ingestion example
│   └── load_to_sqlite.py    # load orders_clean.csv -> data/portfolio.db
├── sql/
│   ├── dim_customers.sql
│   ├── serving_table.sql
│   ├── data_quality_checks.sql   # grain check + reconciliation check
│   └── practice/             # solo SQL practice, not part of the pipeline
├── airflow/
│   ├── dags/orders_pipeline_dag.py
│   └── docker-compose.yaml
├── tests/
│   └── test_clean_order.py
├── docs/
│   ├── architecture.md
│   ├── data_model.md
│   ├── runbook.md
│   └── cloud_mapping.md
└── data/
    ├── raw/       # original source data
    ├── staging/   # after clean/dedup + watermark
    └── serving/   # downstream-ready output
```

## Trade-offs: why batch first

- Order data doesn't need second-level freshness — a daily revenue summary (refreshed once a day) already answers the questions the business actually asks (e.g. "how did yesterday compare to the day before").
- Batch is much easier to write, debug, and reason about — every script here (`clean_order.py`, `extract_api.py`, `daily_summary.py`) runs to completion and produces a fixed, inspectable output. Streaming adds ordering, deduplication, checkpointing, and late-data handling on top — complexity that isn't worth it unless the business actually needs real-time.
- Standard progression: start with batch, move to micro-batch if lower latency is needed, and only reach for real streaming (Kafka + a stream processor) when the business case genuinely requires near-real-time.

## Reliability: Idempotency, Incremental Load, Data Quality

### Idempotency (proven, not just claimed)

`src/clean_order.py` produces the same result no matter how many times it's rerun — no duplicates. Verified by running it 3 times in a row against the same data:

| Run | `dupe_id_check` (new order_ids found) | Lines in `orders_clean.csv` |
|---|---|---|
| 1 (first run, empty watermark) | 19 order_ids | 13 (1 header + 12 clean rows) |
| 2 (immediate rerun) | 0 (empty — every row is older than the watermark and gets skipped) | 13 (unchanged) |
| 3 (rerun again) | 0 | 13 (unchanged) |

Also verified no duplicate `order_id` in the output file (`uniq -d` on the `order_id` column returns nothing) and no duplicate header rows mid-file.

### Incremental Load via Watermark

- `data/staging/_watermark.txt` stores a single scalar value: the highest `updated_at` processed so far (not a column in the main table — a separate bookmark file).
- Every run of `clean_order.py`: read the existing watermark, skip any row where `updated_at <= watermark` (only new data gets processed), then after processing compute a new watermark from `max(updated_at)` of this run and overwrite the file.
- Clean output is written in **append** mode to `orders_clean.csv` (not overwrite) so results accumulate across runs, with a check for whether the file already exists before deciding whether to call `writeheader()` again.

### Backfill (manual, not automated yet)

To reprocess all data from scratch (e.g. after a validation logic fix that needs to be applied retroactively): delete `data/staging/_watermark.txt` and `data/staging/orders_clean.csv`, then rerun `clean_order.py`. This is equivalent to a full backfill since the watermark resets to its minimum value and every row gets processed again.

### Data Quality Checks currently in place

| Check | Rule | Stored in |
|---|---|---|
| Duplicate `order_id` | Keep only the row with the latest `updated_at` | `dupe_id_check` |
| Null / N/A | Every column | `null_row` |
| Amount not numeric / negative | Must parse to float and be >= 0 | `wrong_num_type` |
| Bad datetime format | `created_at`/`updated_at` must parse as `%Y-%m-%d %H:%M:%S` | `wrong_date_time` |

## Orchestration: Airflow

`airflow/dags/orders_pipeline_dag.py` runs the pipeline on a schedule instead of manually invoking each script.

```
validate_and_clean_orders  >>  build_daily_summary
   (src/clean_order.py)         (src/daily_summary.py)
```

- Only 2 tasks, matching where the actual work boundaries already are in the codebase — `clean_order.py` does extract+validate+dedup+incremental-load in one script, `daily_summary.py` does transform+load-to-serving. Splitting further would create tasks with no independent meaning, just to hit an arbitrary "4 tasks" count.
- **Executor**: LocalExecutor (no Celery/Redis) — this DAG has 2 sequential tasks total, a distributed worker queue would be pure overhead for a project this size.
- **Retry-safety connects directly to the idempotency work above**: `default_args` sets `retries: 1`. If `validate_and_clean_orders` fails partway and Airflow retries it, the retry re-reads the same watermark file and produces the same result — no duplicate rows — because the task itself is idempotent (verified separately, see Reliability section above). Retries are only safe to configure *because* the underlying script was already proven idempotent; retrying a non-idempotent task would just multiply the damage.
- Verified with a real manual trigger (`airflow dags trigger orders_pipeline`): both tasks exited 0; `validate_and_clean_orders` correctly read the existing watermark and found 0 new rows (proving Airflow is operating on the same persistent state as manual runs, not an isolated copy); `build_daily_summary` reproduced the same 8-row summary as the manual run.

### How to run Airflow locally

```bash
cd airflow
docker compose up -d          # first run takes ~1-2 min (db init)
docker compose ps             # wait until all containers show "healthy"

# UI: http://localhost:8081  (user: airflow / pass: airflow)
# or trigger from CLI:
docker compose exec airflow-apiserver airflow dags unpause orders_pipeline
docker compose exec airflow-apiserver airflow dags trigger orders_pipeline
```

## Data Model

Star schema: 1 fact table + 1 dimension table + 1 serving table. Grain for each table is proven with a real SQL query, not just documented as a design intent — full details in [`docs/data_model.md`](docs/data_model.md)

| Table | Type | Grain |
|---|---|---|
| `orders` | Fact | 1 order / row |
| `dim_customers` | Dimension | 1 customer / row |
| `daily_orders_summary` | Serving | 1 day / row |

SQL lives in [`sql/dim_customers.sql`](sql/dim_customers.sql), [`sql/serving_table.sql`](sql/serving_table.sql); grain and reconciliation checks are in [`sql/data_quality_checks.sql`](sql/data_quality_checks.sql) (data is loaded into SQLite via `src/load_to_sqlite.py` → `data/portfolio.db`).

## Failure Handling

- **Logging**: `src/clean_order.py` writes to `logs/pipeline.log` (level INFO and up) instead of just printing — kept for review after the terminal is closed.
- **Error isolation**: rows that fail validation (null/negative amount/bad date format) are routed to `dirty_rows` instead of failing the whole pipeline — one bad row doesn't affect the others.
- **Retry**: the Airflow DAG sets `retries: 1` (see [Notes: Retry Strategy](#notes-retry-strategy)) — safe because the pipeline is idempotent.
- **Runbook**: common failure symptoms, diagnosis steps, and backfill instructions are in [`docs/runbook.md`](docs/runbook.md)

## Monitoring

Checklist to run after every pipeline execution (full detail in [`docs/runbook.md`](docs/runbook.md#5-monitoring-checklist)):

- **Freshness** — the watermark actually advances when new data arrives.
- **Row count** — row growth is within a reasonable range.
- **Duplicate check** — no duplicate `order_id` in `orders_clean.csv`.
- **Dirty row ratio** — the proportion of bad rows isn't increasing abnormally.

This is currently a manual checklist (run the checks by hand); not yet wired to automated alerting — the next step would be a CloudWatch/Datadog alert on these values.

## Testing

Unit tests for the logic most likely to break silently (`src/clean_order.py` > `validate_row()`):

```bash
venv/Scripts/python.exe -m pytest tests/ -v
```

## Integration Verified (2026-09-13)

Full pipeline run end-to-end in one pass via an Airflow trigger (not just each script run separately):

```
Airflow trigger orders_pipeline
  -> clean_order.py (extract -> deduplicate -> validate -> load)
  -> daily_summary.py (aggregate)
  -> load_to_sqlite.py (load to data/portfolio.db)
  -> SQL grain check: (12, 12) OK
  -> SQL reconciliation check: (24650.5, 24650.5) OK
  -> pytest: 3 passed
```

No new bugs surfaced during this integration run — a result of the data quality checks and unit tests added during Day 17-19, not an indication that no edge cases remain.

## Progress Log

| Week | What was added |
|---|---|
| Week 1 | SQL analytics queries (JOIN, window functions), Python ingestion script, API extraction |
| Week 2 | Storage design, ETL/ELT pipeline, incremental load, Airflow DAG |
| Week 3 | Docker, cloud mapping, production monitoring, data modeling (star schema) |
| Week 4 | Portfolio polish, final pipeline integration |

## Tech Stack

- SQL (SQLite for development, PostgreSQL for production)
- Python
- Airflow (orchestration)
- Docker
- AWS (S3, ECS/Batch, MWAA, RDS/DynamoDB — conceptual mapping, see [`docs/cloud_mapping.md`](docs/cloud_mapping.md))
- pytest (unit tests)
- `logging` (Python standard library)

## Source

| File | Source | Description |
|---|---|---|
| `data/raw/orders_raw.csv` | Hand-crafted mock data | 20 orders with intentional dirty-data edge cases (comma-formatted amount, null, negative, bad date, duplicate order_id) |
| `data/raw/posts_raw.jsonl` | [JSONPlaceholder API](https://jsonplaceholder.typicode.com/posts) | Mock REST API used to practice JSONL extraction, one JSON object per line |
| `data/staging/orders_clean.csv` | Derived from `orders_raw.csv` | Output after validation by `src/clean_order.py` (dedup by latest `updated_at`, null check, amount/datetime validation) — written in append mode as part of incremental load |
| `data/staging/_watermark.txt` | Generated by `src/clean_order.py` | Watermark file — stores the latest `updated_at` processed, used for incremental load |
| `data/serving/daily_orders_summary.csv` | Derived from `orders_clean.csv` | Daily revenue summary (`order_date`, `count`, `amount`) built by `src/daily_summary.py` — the project's first serving output |

## Config

Create a `.env` file (see `.env.example`) — not committed, since it holds config that varies by environment:

```
API_URL=https://jsonplaceholder.typicode.com/posts
```

## How to Run

```bash
# 1. Create and activate a virtual environment (one-time setup)
python -m venv venv
.\venv\Scripts\Activate.ps1        # Windows PowerShell

# 2. Install dependencies
python -m pip install -r requirements.txt

# 3. Run the scripts
python src/clean_order.py          # clean orders_raw.csv -> data/staging/orders_clean.csv
python src/extract_api.py          # extract API -> data/raw/posts_raw.jsonl
python src/daily_summary.py        # aggregate orders_clean.csv -> data/serving/daily_orders_summary.csv
python src/load_to_sqlite.py       # load orders_clean.csv -> data/portfolio.db (for running sql/*.sql)
```

### Option 2: Docker (no local Python/venv needed)

```bash
docker build -t de-portfolio .
docker run --rm de-portfolio          # default: runs src/clean_order.py
docker run --rm de-portfolio python src/daily_summary.py   # override the default command
```

Note: `COPY . .` in the `Dockerfile` is a **build-time snapshot**, not a live mount — the data inside the image is frozen at build time. Editing `data/raw/orders_raw.csv` locally requires a `docker build` rerun to see the change (unlike the Airflow setup below, which uses live `volumes:`).

Cloud mapping (how this local architecture maps to AWS): [`docs/cloud_mapping.md`](docs/cloud_mapping.md)

## What I Learned

- **Rerun-safe (idempotent) pipeline design** — a watermark bookmark plus dedup-by-latest-timestamp means reruns always produce the same result, proven with an actual rerun test rather than just claimed by design.
- **Data validation needs to be a separate concern from transform logic** — the first version mixed both into one loop, which made debugging hard. Splitting into `extract/deduplicate/validate_row/load` surfaced a hidden bug (`is_dirty` left unbound when a row was clean) that had been invisible before.
- **Retry is only safe when the task is idempotent** — turning on `retries` in Airflow without that guarantee can compound an error instead of fixing it.
- **Grain has to be defined and proven with a real query**, not just asserted — a reconciliation check between the fact and serving tables catches bugs that documentation alone can't.
- **Windows has its own environment gotchas** worth knowing (PATH issues with non-default installs, UTF-16 vs UTF-8 encoding, Docker Desktop's WSL2 file locks) — the kind of thing you only really learn by hitting it.

## Next Improvements

- Add CI (GitHub Actions) to run `pytest` automatically on every push instead of by hand.
- Add a schema contract check (validate that the input CSV has the expected columns before it enters the pipeline).
- Turn the current manual monitoring checklist into real automated alerting (e.g. wired to CloudWatch per the cloud mapping).
- Add SCD Type 2 to `dim_customers` if customer attributes that change over time are added later (see the known limitation in `docs/data_model.md`).
- Test against a larger data volume (currently tested against 20 rows of mock data).

## Notes: Retry Strategy

- **Should retry**: timeouts, connection errors, HTTP 5xx (500, 502, 503) — server/network errors that are usually transient and may succeed on retry.
- **Should not retry**: HTTP 4xx (400, 401, 404) — errors caused by the request itself (bad URL, missing permission, resource doesn't exist). Retrying just fails the same way every time; the request needs to be fixed first.
