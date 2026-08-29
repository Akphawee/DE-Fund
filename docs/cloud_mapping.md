# Cloud Mapping (AWS)

Local component ตอนนี้ (Docker + flat files บนเครื่อง) แมปไปเป็น AWS service จริงยังไง — ยังไม่ได้ deploy จริง แค่แสดงว่า architecture ที่ทำมาแปลงเป็น production cloud setup ได้อย่างไร

| Local ตอนนี้ | AWS Service | เหตุผล |
|---|---|---|
| `data/raw/`, `data/staging/`, `data/serving/` (flat CSV/JSONL files) | **S3** | Object storage เก็บไฟล์แบบ folder structure ได้ตรงๆ (`s3://bucket/raw/`, `s3://bucket/staging/`, `s3://bucket/serving/`) ราคาถูก เป็นมาตรฐานของ data lake |
| `src/clean_order.py`, `src/daily_summary.py` (รันผ่าน `Dockerfile` ที่เพิ่ง build) | **ECS Fargate** หรือ **AWS Batch** | มี Docker image พร้อมอยู่แล้ว — สอง service นี้รัน container image ตรงๆ แบบ serverless ไม่ต้องดูแล server เอง ต่างจาก Lambda ที่เหมาะกับงานสั้น/เบา (มี time limit 15 นาที, memory limit) มากกว่างาน pipeline |
| Airflow (ตั้งเองผ่าน Docker Compose, `airflow/`) | **Amazon MWAA** (Managed Workflows for Apache Airflow) | Airflow ตัวเดียวกันเป๊ะ แค่ AWS จัดการ infra เบื้องหลัง (postgres, scheduler, worker, scaling) แทนที่จะดูแลเอง |
| `data/staging/_watermark.txt` (scalar state ตัวเดียว) | **DynamoDB** (หรือ Parameter Store สำหรับ config ง่ายๆ) | ต้อง read/write ค่าเดียวบ่อยๆ ทุกรอบ pipeline — DynamoDB (key-value db) เหมาะกว่าไฟล์บน S3 เพราะ S3 ไม่ได้ออกแบบมาสำหรับ update ค่าเดิมซ้ำถี่ๆ |
| Postgres ภายใน Airflow container (metadata db) | **RDS** (managed PostgreSQL) | MWAA จัดการให้อยู่แล้วเบื้องหลัง แต่ถ้าตั้ง Airflow เองบน EC2/ECS ก็ต้องมี RDS แยกสำหรับ metadata db |

## หลักการรวบ (จำ pattern นี้พอ ไม่ต้องจำทุก service)

- Local file / flat file storage → **S3**
- Local compute (script, container) → **ECS / Batch / Lambda** (เลือกตามขนาดงาน — งานสั้นเบา = Lambda, งานหนัก/ใช้ container อยู่แล้ว = ECS/Batch)
- Local orchestrator (Airflow) → **MWAA**
- Local database → **RDS** (relational) หรือ **DynamoDB** (key-value/state)

## หมายเหตุ

Mapping นี้เป็น conceptual เท่านั้น ยังไม่ได้ deploy จริงบน AWS — เป้าหมายคือแสดงให้เห็นว่า local architecture ที่ทำมาตลอดโปรเจกต์ (source → raw → staging → serving, ดู [`architecture.md`](architecture.md)) ไม่ใช่แค่ของเล่นสำหรับฝึก แต่ scale ไปเป็น production cloud setup ได้โดยไม่ต้องเปลี่ยน design หลัก แค่เปลี่ยนตัว implementation ของแต่ละ component
