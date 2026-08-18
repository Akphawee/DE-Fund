# Architecture

## Flow

```
Source (app/API)
      |
      v
   raw/            <- exact copy, untouched, kept for reprocessing/debugging
      |
      v
   staging/        <- validated + cleaned, same grain as source (1 row = 1 order)
      |
      v
   serving/        <- aggregated / shaped for how it's actually consumed (not built yet)
```

| Stage | Folder | Status | What lives here |
|---|---|---|---|
| Source | (external) | - | The system that generates the data — mocked here as `orders_raw.csv` and the JSONPlaceholder API |
| Raw | `data/raw/` | Done | Untouched copy of source data (`orders_raw.csv`, `posts_raw.jsonl`). Never modified — if a downstream bug is found, reprocessing starts from here instead of re-pulling from source |
| Staging | `data/staging/` | Done | Cleaned + validated, still row-per-order grain (`orders_clean.csv`, produced by `src/clean_order.py`) |
| Serving | `data/serving/` | Not built yet | Aggregated tables shaped for actual consumption (e.g. `daily_orders_summary`) — planned for Week 2 |

## Why raw is kept separate and untouched

Ties back to the ETL vs ELT tradeoff: raw data is loaded first and kept as-is so that if the transform logic
in `clean_order.py` has a bug, it can be fixed and re-run against `data/raw/` without needing to go back to
the source system. This is also what makes **backfill** possible later — you can't recompute a past date
correctly if the raw data for that date was never kept.

## Storage: OLTP vs OLAP

- The mocked source (`orders_raw.csv`) represents an **OLTP**-style system: row-oriented, optimized for
  writing/updating individual records fast (a real e-commerce app's live database).
- The eventual `serving/` layer is **OLAP**-style: optimized for reading/aggregating across many rows at once
  (e.g. `SUM(amount) GROUP BY order_date`), which favors a column-oriented format.

## File formats used and why

| Format | Used for | Why |
|---|---|---|
| CSV | `data/raw/orders_raw.csv`, `data/staging/orders_clean.csv` | Row-oriented, human-readable — easy to eyeball while debugging a small dataset |
| JSONL | `data/raw/posts_raw.jsonl` | Matches the shape of the API response (nested-capable), one record per line so it can be read without loading the whole file into memory |
| Parquet | Not used yet | Planned for `serving/` once queries become aggregate-heavy — column-oriented, only reads the columns a query actually needs (same idea as `SELECT` column pruning from `sql/interview_set_02_answers.sql` Q3/Q12, just baked into the file format instead of the query) |

## Partitioning (not implemented yet)

Once a `serving/` layer exists, output would be partitioned by `order_date` (e.g. one file per day) so a
query for "yesterday's orders" only reads yesterday's partition instead of scanning everything —
same "partition pruning" idea covered in `sql_interview_set_02.pdf` Q3.
