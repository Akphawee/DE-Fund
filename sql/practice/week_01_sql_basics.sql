-- Week 1 Day 1 — SQL Basics Practice
-- SELECT / WHERE / GROUP BY / ORDER BY / DISTINCT / aggregate / INNER JOIN
-- รันกับ practice.db (premium_bundle/sql_practice/practice.db)

-- 1. Order ทั้งหมดที่ status = 'cancelled'
SELECT * FROM orders WHERE status = 'cancelled';

-- 2. Customer ทั้งหมดใน province = 'Bangkok'
SELECT * FROM customers WHERE province = 'Bangkok';

-- 3. Order ที่ amount มากกว่า 5000
SELECT * FROM orders WHERE amount > 5000;

-- 4. Top 5 order ที่ amount สูงสุด
SELECT * FROM orders ORDER BY amount DESC LIMIT 5;

-- 5. Province ทั้งหมดที่มีลูกค้าอยู่ (ไม่ซ้ำ) -- ใช้ DISTINCT เพราะไม่มีการคำนวณ ไม่ต้อง GROUP BY
SELECT DISTINCT province FROM customers;

-- 6. นับจำนวน order ต่อ status
SELECT COUNT(*), status FROM orders GROUP BY status;

-- 7. ยอดขายรวม เฉพาะ order ที่จ่ายสำเร็จ
SELECT SUM(amount) FROM orders WHERE status = 'paid';

-- 8. Category สินค้าที่ราคาเฉลี่ยสูงสุด -- ใช้ GROUP BY เพราะต้องคำนวณ AVG ต่อกลุ่ม
SELECT category, AVG(price) AS avg_price
FROM products
GROUP BY category
ORDER BY avg_price DESC;

-- 9. จำนวนลูกค้าในแต่ละ province
SELECT COUNT(customer_id), province FROM customers GROUP BY province;

-- 10. Order ที่ paid และ amount > 3000 พร้อมชื่อลูกค้า (JOIN)
SELECT c.name AS customer_name, o.order_id, o.amount
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
WHERE o.amount > 3000 AND o.status = 'paid';
