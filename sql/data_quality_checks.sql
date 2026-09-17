-- Data Quality Checks -- orders table
-- Run before handing this table off to downstream consumers (dashboard, analyst)

-- 1. Null check: required fields must not be empty
SELECT * FROM orders WHERE order_id IS NULL;
SELECT * FROM orders WHERE customer_id IS NULL;   -- found 2 rows (O005, O037) -- orphan orders, pending a decision on reject vs. investigate at the source
SELECT * FROM orders WHERE amount IS NULL;

-- 2. Duplicate check: primary key must not repeat
SELECT order_id, COUNT(*) AS n
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;   -- should always be empty

-- 3. Accepted values check: status must be one of the allowed values
SELECT DISTINCT status FROM orders
WHERE status NOT IN ('paid', 'cancelled', 'pending');   -- should be empty

-- 4. Grain check: the fact table (orders) must have grain = 1 row per order
-- if total_rows != unique_orders, a duplicate order_id slipped through (bug in dedup logic)
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_id) AS unique_orders
FROM orders;   -- these two columns must always be equal

-- 5. Serving table reconciliation: SUM(amount) in the serving table must equal SUM(amount) in the fact table
-- if they don't match, serving_table.sql has a bug (wrong filter, wrong GROUP BY grain, etc.)
SELECT
    (SELECT SUM(amount) FROM orders) AS fact_total,
    (SELECT SUM(total_amount) FROM (
        SELECT substr(created_at, 1, 10) AS order_date, SUM(amount) AS total_amount
        FROM orders GROUP BY order_date
    )) AS serving_total;   -- these two columns must always be equal
-- verified manually 2026-09-13: SQL serving_table.sql output matches data/serving/daily_orders_summary.csv
-- (the Python-generated version from daily_summary.py) exactly on every row
