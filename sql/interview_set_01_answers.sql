-- Week 1 Day 2 — sql_interview_set_01.pdf (10/10 ข้อ)
-- รันกับ practice.db (premium_bundle/sql_practice/practice.db)

-- Q1: Top 3 ลูกค้าที่ใช้จ่ายเยอะสุดในแต่ละ province
WITH customer_spend AS (
    SELECT o.customer_id, c.province, SUM(o.amount) AS total_amount
    FROM orders o
    INNER JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.status = 'paid'
    GROUP BY o.customer_id
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY province ORDER BY total_amount DESC) AS rn
    FROM customer_spend
)
SELECT * FROM ranked WHERE rn <= 3;

-- Q2: นับจำนวน order ต่อวัน (grain ของ order_items คือ 1 item ไม่ใช่ 1 order -- ต้อง COUNT DISTINCT)
SELECT COUNT(DISTINCT oi.order_id) AS order_count, o.order_date
FROM order_items oi
INNER JOIN orders o ON o.order_id = oi.order_id
GROUP BY o.order_date;

-- Q4: Order ล่าสุดของลูกค้าแต่ละคน
WITH ranked AS (
    SELECT customer_id, order_date,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
    FROM orders
)
SELECT * FROM ranked WHERE rn = 1;

-- Q5: ยอดขายรายวันเทียบกับวันก่อนหน้า
WITH daily AS (
    SELECT order_date, SUM(amount) AS total_sum
    FROM orders
    WHERE status = 'paid'
    GROUP BY order_date
)
SELECT *, total_sum - LAG(total_sum) OVER (ORDER BY order_date) AS daily_diff
FROM daily;

-- Q6: หา email ที่ซ้ำกันในตาราง customers
SELECT email, COUNT(email) AS n
FROM customers
GROUP BY email
HAVING COUNT(email) > 1;

-- Q7: Order ที่ยังไม่มี payment สำเร็จ (anti join -- เงื่อนไข success ต้องอยู่ใน ON ไม่ใช่ WHERE)
SELECT o.order_id, o.status AS order_status, p.status AS payment_status
FROM orders o
LEFT JOIN payments p ON o.order_id = p.order_id AND p.status = 'success'
WHERE p.order_id IS NULL;

-- Q8: Top 3 สินค้าตาม revenue ในแต่ละ category
WITH product_revenue AS (
    SELECT p.name AS product_name, p.category, SUM(oi.item_amount) AS total_price
    FROM order_items oi
    INNER JOIN products p ON oi.product_id = p.product_id
    GROUP BY oi.product_id
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY category ORDER BY total_price DESC) AS rn
    FROM product_revenue
)
SELECT * FROM ranked WHERE rn <= 3;

-- Q10: ยอดขายสะสมรายวัน (running total)
WITH daily AS (
    SELECT order_date, SUM(amount) AS daily_total
    FROM orders
    WHERE status = 'paid'
    GROUP BY order_date
)
SELECT *, SUM(daily_total) OVER (ORDER BY order_date) AS running_total
FROM daily;

-- Q14: Dedup customer -- เก็บแถวที่ signup_date ล่าสุดต่อ email (rerun-safe pattern)
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS rn
    FROM customers
)
SELECT * FROM ranked WHERE rn = 1;

-- Q15: Data quality checks (ดูไฟล์แยก data_quality_checks.sql)
