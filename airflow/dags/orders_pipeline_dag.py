"""
Daily DAG: clean+dedup orders_raw.csv (incremental via watermark, see
src/clean_order.py) -> aggregate into daily_orders_summary.csv
(src/daily_summary.py).

Only 2 tasks because that's where the real work boundaries are in this
project: clean_order.py already does extract+validate+dedup+incremental-load
in one script, daily_summary.py does transform+load-to-serving. Splitting
further would just create tasks with no independent meaning.
"""

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator

default_args = {
    "owner": "de-portfolio",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="orders_pipeline",
    description="Clean+dedup orders_raw.csv (incremental) then aggregate into daily_orders_summary.csv",
    default_args=default_args,
    schedule="0 6 * * *",  # daily at 06:00
    start_date=datetime(2026, 8, 29),
    catchup=False,
    tags=["de-portfolio", "orders"],
) as dag:

    validate_and_clean = BashOperator(
        task_id="validate_and_clean_orders",
        bash_command="cd /opt/deportfolio && python3 src/clean_order.py",
    )

    build_daily_summary = BashOperator(
        task_id="build_daily_summary",
        bash_command="cd /opt/deportfolio && python3 src/daily_summary.py",
    )

    validate_and_clean >> build_daily_summary
