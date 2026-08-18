# E-commerce Order Analytics Pipeline

> Status: 🚧 In Progress — Day 8 / 28 (เริ่ม 2026-08-07)

## Problem

ร้านค้าออนไลน์มีข้อมูล orders, customers, products ไหลเข้ามาทุกวัน แต่ข้อมูลดิบมักมีปัญหา: duplicate record, orphan order (ไม่มี customer จริง), payment ที่ status ไม่ตรงกับ order, ทำให้ทีม business ดูยอดขายผิดหรือ query ยาก

โปรเจกต์นี้สร้าง pipeline ที่ดึงข้อมูล, ตรวจสอบคุณภาพ, แปลงข้อมูล, และส่งออกเป็น serving table ที่ทีม analytics ใช้ตอบคำถามธุรกิจได้ทันที เช่น "ลูกค้ากลุ่มไหนใช้จ่ายเยอะสุดในแต่ละจังหวัด" หรือ "ยอดขายรายวันเทียบกับวันก่อนหน้าเป็นยังไง"

## Architecture (จะเพิ่มขึ้นเรื่อย ๆ ตามที่เรียน)

```
Source (CSV/API) → raw/ → staging/ → serving/
                                          ↓
                                Orchestrated by Airflow (Week 2)
```

รายละเอียดเต็ม (OLTP vs OLAP, ทำไม raw ต้องแยกเก็บ, เลือก file format ยังไง) ดูที่ [`docs/architecture.md`](docs/architecture.md)

## Progress Log

| Week | สิ่งที่เพิ่มเข้ามา |
|---|---|
| Week 1 | SQL analytics queries (JOIN, window functions), Python ingestion script, API extraction |
| Week 2 | Storage design, ETL/ELT pipeline, incremental load, Airflow DAG |
| Week 3 | Docker, cloud mapping, production monitoring, data modeling (star schema) |
| Week 4 | Portfolio polish, final pipeline integration |

## Tech Stack

- SQL (SQLite ตอนฝึก → PostgreSQL ตอน production-ready)
- Python
- Airflow (orchestration)
- Docker

## Source

| File | Source | Description |
|---|---|---|
| `data/raw/orders_raw.csv` | Hand-crafted mock data | 20 orders พร้อม intentional dirty-data edge case (comma-formatted amount, null, negative, bad date, duplicate order_id) |
| `data/raw/posts_raw.jsonl` | [JSONPlaceholder API](https://jsonplaceholder.typicode.com/posts) | Mock REST API ฝึก extract แบบ JSONL, 1 JSON object ต่อบรรทัด |
| `data/staging/orders_clean.csv` | Derived from `orders_raw.csv` | ผลลัพธ์หลัง validate ด้วย `src/clean_order.py` (dedup, null check, amount/datetime validation) |

## Config

สร้างไฟล์ `.env` (ดูตัวอย่างที่ `.env.example`) — ไม่ commit ไฟล์นี้จริง เพราะเก็บ config ที่อาจเปลี่ยนตาม environment:

```
API_URL=https://jsonplaceholder.typicode.com/posts
```

## How to Run

```bash
# 1. สร้างและเปิดใช้ virtual environment (ครั้งแรกครั้งเดียว)
python -m venv venv
.\venv\Scripts\Activate.ps1        # Windows PowerShell

# 2. ติดตั้ง dependency
python -m pip install -r requirements.txt

# 3. รัน script
python src/clean_order.py          # clean orders_raw.csv -> data/staging/orders_clean.csv
python src/extract_api.py          # extract API -> data/raw/posts_raw.jsonl
```

## Notes: Retry Strategy

- **ควร retry**: timeout, connection error, HTTP 5xx (500, 502, 503) — เป็น error ฝั่ง server/network ที่มักเป็นปัญหาชั่วคราว retry แล้วอาจสำเร็จ
- **ไม่ควร retry**: HTTP 4xx (400, 401, 404) — เป็น error จาก request เอง (URL ผิด, ไม่มี permission, ข้อมูลไม่มีอยู่จริง) retry ซ้ำก็จะพังเหมือนเดิมทุกครั้ง ต้องแก้ request ก่อน ไม่ใช่ retry
