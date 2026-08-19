# Compute Notes

## Who does what in a pipeline

| Role | Job | Example in this project |
|---|---|---|
| **cron** | Time-based scheduler — just triggers a script/job at a set time. No awareness of data, events, or dependencies. | Not used yet — will be replaced by Airflow (Week 2, Day 12-13), which is essentially "cron + retry + dependency tracking + monitoring" |
| **script (Python)** | Where extract/clean/transform logic actually runs, row by row or in memory | `src/clean_order.py` (extract + validate + transform), `src/extract_api.py` (extract), `src/daily_summary.py` (transform/aggregate) |
| **SQL engine** | Executes queries (JOIN, GROUP BY, aggregate) against stored data — same transform work as a script, just expressed as SQL instead of a loop | SQLite engine used for `sql/interview_set_02_answers.sql` — the same `daily_orders_summary` aggregation could be written as one `GROUP BY` query instead of the dict-based loop in `daily_summary.py` |
| **data warehouse** | Where the output of compute is stored so others can query it | `data/serving/` (currently flat files; a real warehouse — Postgres/Snowflake/BigQuery — would replace this later) |

Cron and Airflow don't do compute themselves — they just decide *when* the script/SQL engine runs. Easy to
confuse "what schedules the work" with "what does the work."

## Batch vs streaming vs near-real-time (recap + Spark/Kafka overview)

Already covered in the Day 6 concept review — see `sql/mistake_log.md` history for the batch vs streaming
questions. New this session: a one-line overview of the tools that batch/streaming outgrow into once volume
is very high (not needed for a junior role, just good to recognize the names):

- **Spark**: a compute engine for processing large batch (or micro-batch) datasets across multiple machines,
  used when a single script/SQL engine can't handle the data volume on one machine anymore.
- **Kafka**: a message queue for streaming — producers publish events, consumers read them (in
  partitions, for parallelism). This is the actual "distribute events to consumers" idea that got
  confused with cron earlier this session — cron is a clock, Kafka is an event pipe. Different problems.

## Why this project starts with batch, not streaming

- Order data doesn't need sub-second freshness — a daily summary refreshed once a day is enough for the
  business questions this project answers (e.g. "yesterday's revenue vs the day before").
- Batch is much simpler to build, debug, and reason about — every script written so far
  (`clean_order.py`, `extract_api.py`, `daily_summary.py`) runs start to finish and produces a fixed,
  inspectable output. Streaming adds real complexity (ordering, duplicates, checkpointing, late data —
  see `sql/mistake_log.md` on late-arriving data) that isn't worth taking on until batch genuinely can't
  meet the latency the business needs.
- Standard progression: start batch → move to micro-batch if latency needs to drop → only reach for true
  streaming (Kafka + a stream processor) if the business case actually requires near-real-time.
