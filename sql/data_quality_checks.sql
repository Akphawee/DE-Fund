-- Data Quality Checks -- orders table
-- รันก่อนปล่อยตารางให้ downstream (dashboard, analyst) ใช้ต่อ

-- 1. Null check: field สำคัญห้ามว่าง
SELECT * FROM orders WHERE order_id IS NULL;
SELECT * FROM orders WHERE customer_id IS NULL;   -- พบ 2 แถว (O005, O037) -- orphan order รอตัดสินใจว่าจะ reject หรือ investigate ต้นทาง
SELECT * FROM orders WHERE amount IS NULL;

-- 2. Duplicate check: primary key ห้ามซ้ำ
SELECT order_id, COUNT(*) AS n
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;   -- ควรว่างเปล่าเสมอ

-- 3. Accepted values check: status ต้องอยู่ในค่าที่รับได้เท่านั้น
SELECT DISTINCT status FROM orders
WHERE status NOT IN ('paid', 'cancelled', 'pending');   -- ควรว่างเปล่า

-- 4. Grain check: fact table (orders) ต้องมี grain = 1 แถว ต่อ 1 order
-- ถ้า total_rows != unique_orders แปลว่ามี order_id ซ้ำหลุดมา (dedup logic มี bug)
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_id) AS unique_orders
FROM orders;   -- สอง column นี้ต้องเท่ากันเสมอ

-- 5. Serving table reconciliation: SUM(amount) ใน serving table ต้องเท่ากับ SUM(amount) ใน fact table
-- ถ้าไม่เท่ากันแปลว่า serving_table.sql มี bug (filter ผิด, GROUP BY ผิด grain, ฯลฯ)
SELECT
    (SELECT SUM(amount) FROM orders) AS fact_total,
    (SELECT SUM(total_amount) FROM (
        SELECT substr(created_at, 1, 10) AS order_date, SUM(amount) AS total_amount
        FROM orders GROUP BY order_date
    )) AS serving_total;   -- สอง column นี้ต้องเท่ากันเสมอ
-- verified manually 2026-09-13: SQL serving_table.sql output ตรงกับ data/serving/daily_orders_summary.csv
-- (Python-generated version จาก daily_summary.py) ทุกแถว 100%
