# Runbook

pipeline พังตอนตี 3 (หรือเวลาไหนก็ตาม) — เช็คอะไรก่อน แก้ยังไง

## 1. เช็คว่าพังจริงมั้ย และพังตรงไหน

```bash
tail -50 logs/pipeline.log
```

ดู log ล่าสุด หา level `ERROR` — ข้อความ error จะบอกตรงๆ ว่าพังที่ฟังก์ชันไหน (`read_watermark`, `extract`, `deduplicate`, `validate_row`, `load`)

ถ้ารันผ่าน Airflow ให้ดู task log ใน UI (`http://localhost:8081`) หรืออ่านตรงจาก `airflow/logs/dag_id=orders_pipeline/run_id=.../`

## 2. อาการที่เจอบ่อย และวิธีแก้

| อาการ | สาเหตุที่เป็นไปได้ | เช็คยังไง |
|---|---|---|
| `FileNotFoundError` ตอน `extract()` | ไฟล์ raw ยังไม่มา หรือ path ผิด | เช็คว่า `data/raw/orders_raw.csv` มีอยู่จริง และ mtime ล่าสุดตรงกับที่คาด |
| pipeline รันผ่านแต่ `orders_clean.csv` ไม่มี row ใหม่เพิ่ม | ปกติถ้าไม่มี order ใหม่จริงๆ (watermark กันไว้) — ไม่ใช่ bug | เช็ค `data/staging/_watermark.txt` เทียบกับ `updated_at` ล่าสุดใน raw data ว่าตรงกันมั้ย |
| row หายไปเยอะผิดปกติ (ไปอยู่ `dirty_rows`) | ข้อมูลต้นทางเสีย (null, negative amount, วันที่ผิด format) | ดู log level `ERROR`/`WARNING` จาก `validate_row` — จะบอกว่า row ไหนติดอะไร |
| watermark ไม่ขยับ (ค่าเดิมตลอด) | ไม่มี row ที่ `updated_at > watermark` เลย หรือ raw data ไม่ได้ถูกอัปเดตจริง | เช็คแหล่งข้อมูลต้นทางว่ามี data ใหม่จริงมั้ย |
| รันซ้ำแล้ว `orders_clean.csv` มี row ซ้ำ | ไม่ควรเกิด — pipeline design เป็น idempotent (ดู README > Reliability) ถ้าเกิดแปลว่ามี bug ใน dedup logic | รัน rerun test ตามที่ README อธิบาย เทียบ line count ก่อน/หลัง |

## 3. Backfill (รันย้อนหลังทั้งหมด)

ถ้าต้อง reprocess ข้อมูลทั้งหมดใหม่ (เช่น พบว่า validate logic เคยมี bug และอยากรันซ้ำ):

```bash
echo '1900-01-01 00:00:00' > data/staging/_watermark.txt
rm -f data/staging/orders_clean.csv
python src/clean_order.py
```

**ระวัง:** คำสั่งนี้ล้าง `orders_clean.csv` ทิ้งแล้วสร้างใหม่ทั้งหมด ห้ามรันบน production data โดยไม่ backup ก่อน

## 4. Unit test ก่อน deploy การแก้ไขใดๆ

```bash
venv/Scripts/python.exe -m pytest tests/ -v
```

ถ้า test ไม่ผ่าน ห้าม deploy — logic เปลี่ยนแล้วพังจุดที่เคยถูกต้อง

## 5. Monitoring checklist (ควรเช็คทุกวันที่ pipeline รัน)

- [ ] **Freshness** — `data/staging/_watermark.txt` ขยับทุกวันที่มี order ใหม่จริง (ถ้าไม่ขยับติดกันหลายวันแต่รู้ว่ามี order ใหม่เข้ามา = ผิดปกติ)
- [ ] **Row count** — จำนวน row ใน `orders_clean.csv` เพิ่มขึ้นในอัตราที่สมเหตุสมผล (ไม่ใช่ 0 ตลอด ไม่ใช่พุ่งผิดปกติ)
- [ ] **Duplicate check** — `order_id` ใน `orders_clean.csv` ไม่ควรซ้ำ (`cut -d',' -f1 data/staging/orders_clean.csv | sort | uniq -d` ควรว่างเปล่า)
- [ ] **Dirty row ratio** — สัดส่วน row ที่ตกไป `dirty_rows` เทียบกับ row ทั้งหมด ไม่ควรเพิ่มขึ้นผิดปกติ (สัญญาณว่าต้นทางข้อมูลเริ่มเสีย)
