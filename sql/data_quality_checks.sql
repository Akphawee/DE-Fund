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
