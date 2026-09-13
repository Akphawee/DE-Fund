# Data Model

Star schema เล็กๆ: fact table 1 ตัว ล้อมด้วย dimension table 1 ตัว, ต่อยอดเป็น serving table 1 ตัวสำหรับ downstream consumer (dashboard/analyst)

## Tables

| Table | Type | Grain | Source | คำอธิบาย |
|---|---|---|---|---|
| `orders` | Fact | 1 แถว = 1 order | `data/staging/orders_clean.csv` (โหลดผ่าน `src/load_to_sqlite.py`) | ข้อมูล order หลังผ่าน dedup + validate จาก `clean_order.py` แล้ว |
| `dim_customers` (view, `sql/dim_customers.sql`) | Dimension | 1 แถว = 1 customer | `orders.customer_id` | unique customer ที่เคยสั่งซื้อ ref จาก fact table ผ่าน `customer_id` |
| `daily_orders_summary` (view, `sql/serving_table.sql`) | Serving | 1 แถว = 1 วัน | `orders` (GROUP BY วันที่จาก `created_at`) | สรุปยอด order รายวัน สำหรับ dashboard/reporting โดยตรง ไม่ต้อง query fact table ดิบ |

## ความสัมพันธ์

```
orders (fact, grain=order)
   |
   |-- ref by customer_id --> dim_customers (grain=customer)
   |
   |-- GROUP BY date(created_at) --> daily_orders_summary (grain=day, serving table)
```

## ทำไมออกแบบแบบนี้

- **Grain ของแต่ละตารางถูกยืนยันด้วย SQL query จริง** ไม่ใช่แค่ design บนกระดาษ — ดู `sql/data_quality_checks.sql`:
  - Check #4: `orders` grain = 1 order/แถว (`COUNT(*) = COUNT(DISTINCT order_id)` → `12 = 12`)
  - Check #5: reconciliation ระหว่าง fact table กับ serving table (`SUM(amount)` ต้องเท่ากันทั้งสองฝั่ง → `24650.5 = 24650.5`)
- **Serving table แยกจาก fact table** เพราะ consumer (เช่น dashboard) ไม่ควร query ตาราง raw/fact ตรงๆ ทุกครั้ง — serving table เป็น pre-aggregated view ที่ query เร็วกว่าและ grain ตรงกับที่ business ต้องการใช้ (รายวัน ไม่ใช่รายออเดอร์)
- **`serving_table.sql` ถูก verify ว่าให้ผลตรงกับ `daily_summary.py` (Python version เดิม) 100%** ทุกแถว — พิสูจน์ว่า SQL version ถูกต้องเทียบกับ logic ที่ verify มาก่อนแล้ว

## Known limitation

- SCD (Slowly Changing Dimension) ยังไม่ implement — `dim_customers` เก็บแค่ `customer_id` ไม่มี attribute อื่น (ชื่อ, region ฯลฯ) และไม่ track การเปลี่ยนแปลงย้อนหลัง ถ้ามี attribute เพิ่มในอนาคตต้องเลือกว่าจะทำ SCD Type 1 (overwrite ค่าเก่า) หรือ Type 2 (เก็บ history ทุกเวอร์ชัน) ตาม use case
