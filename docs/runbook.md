# Runbook

The pipeline breaks at 3am (or any other time) — what to check first, and how to fix it.

## 1. Confirm it actually broke, and where

```bash
tail -50 logs/pipeline.log
```

Check the latest log for `ERROR` level entries — the error message names the function where it failed (`read_watermark`, `extract`, `deduplicate`, `validate_row`, `load`).

If it ran through Airflow, check the task log in the UI (`http://localhost:8081`) or read it directly from `airflow/logs/dag_id=orders_pipeline/run_id=.../`.

## 2. Common symptoms and fixes

| Symptom | Likely cause | How to check |
|---|---|---|
| `FileNotFoundError` during `extract()` | Raw file hasn't arrived yet, or the path is wrong | Confirm `data/raw/orders_raw.csv` exists and its mtime matches expectations |
| Pipeline runs fine but `orders_clean.csv` gets no new rows | Normal if there's genuinely no new order data (the watermark is doing its job) — not a bug | Compare `data/staging/_watermark.txt` against the latest `updated_at` in the raw data |
| Unusually many rows dropped into `dirty_rows` | Bad source data (null, negative amount, bad date format) | Check `ERROR`/`WARNING` level logs from `validate_row` — they name which row failed which check |
| Watermark isn't moving (same value every run) | No row has `updated_at > watermark`, or the raw data genuinely isn't being updated | Check the source system for actual new data |
| Duplicate rows in `orders_clean.csv` after a rerun | Shouldn't happen — the pipeline is designed to be idempotent (see README > Reliability). If it does, there's a bug in the dedup logic | Run the rerun test described in the README, comparing line counts before/after |

## 3. Backfill (reprocess everything)

To reprocess all data from scratch (e.g. after discovering a bug in the validation logic that needs to be re-applied):

```bash
echo '1900-01-01 00:00:00' > data/staging/_watermark.txt
rm -f data/staging/orders_clean.csv
python src/clean_order.py
```

**Warning:** this wipes `orders_clean.csv` and rebuilds it from scratch. Never run this against production data without a backup first.

## 4. Run unit tests before deploying any fix

```bash
venv/Scripts/python.exe -m pytest tests/ -v
```

If tests fail, don't deploy — the logic change broke something that was previously correct.

## 5. Monitoring checklist (run after every pipeline execution)

- [ ] **Freshness** — `data/staging/_watermark.txt` advances on every day with real new orders (if it stays flat for several days while new orders are known to exist, that's abnormal).
- [ ] **Row count** — the row count in `orders_clean.csv` grows at a reasonable rate (not stuck at 0, not spiking abnormally).
- [ ] **Duplicate check** — `order_id` in `orders_clean.csv` should never repeat (`cut -d',' -f1 data/staging/orders_clean.csv | sort | uniq -d` should return nothing).
- [ ] **Dirty row ratio** — the proportion of rows landing in `dirty_rows` relative to total rows shouldn't increase abnormally (a sign the source data is degrading).
