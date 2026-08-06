# E-commerce Order Analytics Pipeline

> Status: 🚧 In Progress — Day 1 / 28 (เริ่ม 2026-08-07)

## Problem

ร้านค้าออนไลน์มีข้อมูล orders, customers, products ไหลเข้ามาทุกวัน แต่ข้อมูลดิบมักมีปัญหา: duplicate record, orphan order (ไม่มี customer จริง), payment ที่ status ไม่ตรงกับ order, ทำให้ทีม business ดูยอดขายผิดหรือ query ยาก

โปรเจกต์นี้สร้าง pipeline ที่ดึงข้อมูล, ตรวจสอบคุณภาพ, แปลงข้อมูล, และส่งออกเป็น serving table ที่ทีม analytics ใช้ตอบคำถามธุรกิจได้ทันที เช่น "ลูกค้ากลุ่มไหนใช้จ่ายเยอะสุดในแต่ละจังหวัด" หรือ "ยอดขายรายวันเทียบกับวันก่อนหน้าเป็นยังไง"

## Architecture (จะเพิ่มขึ้นเรื่อย ๆ ตามที่เรียน)

```
Source (CSV/API) → Extract → Validate → Transform → Load → Serving Table
                                                              ↓
                                                    Orchestrated by Airflow
```

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

## How to Run

_(จะเพิ่มตอน Week 1 เขียน Python script เสร็จ)_
