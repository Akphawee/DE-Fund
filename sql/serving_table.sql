-- serving_table: daily_orders_summary
-- grain: 1 แถว = 1 วัน
-- ref: fact table (orders) grain = 1 order (ดู data_quality_checks.sql #4 สำหรับ grain check ของ fact table)

SELECT
    substr(created_at, 1, 10) AS order_date,
    COUNT(*) AS count,
    SUM(amount) AS total_amount
FROM orders
GROUP BY order_date
ORDER BY order_date;
