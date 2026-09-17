-- serving_table: daily_orders_summary
-- grain: 1 row = 1 day
-- ref: fact table (orders) grain = 1 order (see data_quality_checks.sql #4 for the fact table's grain check)

SELECT
    substr(created_at, 1, 10) AS order_date,
    COUNT(*) AS count,
    SUM(amount) AS total_amount
FROM orders
GROUP BY order_date
ORDER BY order_date;
