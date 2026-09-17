# Cloud Mapping (AWS)

How the current local setup (Docker + flat files on disk) maps to real AWS services — nothing here is actually deployed. The goal is to show how the architecture built in this project would translate into a production cloud setup.

| Local now | AWS Service | Why |
|---|---|---|
| `data/raw/`, `data/staging/`, `data/serving/` (flat CSV/JSONL files) | **S3** | Object storage maps directly onto this folder structure (`s3://bucket/raw/`, `s3://bucket/staging/`, `s3://bucket/serving/`), is cheap, and is the standard for a data lake. |
| `src/clean_order.py`, `src/daily_summary.py` (run via the existing `Dockerfile`) | **ECS Fargate** or **AWS Batch** | A Docker image already exists — both services run a container image directly, serverless, with no servers to manage. Lambda is a better fit for short/light jobs (15-minute time limit, memory limit) than for pipeline workloads. |
| Airflow (self-hosted via Docker Compose, `airflow/`) | **Amazon MWAA** (Managed Workflows for Apache Airflow) | The same Airflow, just with AWS managing the infra behind it (Postgres, scheduler, worker, scaling) instead of self-managing it. |
| `data/staging/_watermark.txt` (a single scalar value) | **DynamoDB** (or Parameter Store for simple config) | This value gets read/written every pipeline run — a key-value store like DynamoDB fits better than a file on S3, since S3 isn't designed for frequent in-place updates. |
| Postgres inside the Airflow container (metadata db) | **RDS** (managed PostgreSQL) | MWAA manages this behind the scenes already, but a self-hosted Airflow on EC2/ECS would need a separate RDS instance for the metadata db. |

## General pattern (this is the part worth remembering, not every individual service)

- Local file / flat file storage → **S3**
- Local compute (script, container) → **ECS / Batch / Lambda** (pick based on job size — short and light = Lambda, heavier or already containerized = ECS/Batch)
- Local orchestrator (Airflow) → **MWAA**
- Local database → **RDS** (relational) or **DynamoDB** (key-value/state)

## Note

This mapping is conceptual only — nothing here has been deployed to AWS. The point is to show that the local architecture built throughout this project (source → raw → staging → serving, see [`architecture.md`](architecture.md)) isn't just a training exercise; it scales into a production cloud setup without changing the core design, only the implementation of each component.
