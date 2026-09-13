-- SQL Interview Set 02: Advanced Patterns
-- Source: premium_bundle/interview_pack/sql_interview_set_02.pdf

-- Question 1: User Sessions
-- Session boundary = gap > 30 minutes from previous event (same user).
-- First event of each user is always a new session.
WITH new_col AS (
    SELECT
        *,
        LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_event_time
    FROM events
),
step2 AS (
    SELECT
        *,
        CASE
            WHEN prev_event_time IS NULL THEN 1
            WHEN (julianday(event_time) - julianday(prev_event_time)) * 24 * 60 > 30 THEN 1
            ELSE 0
        END AS is_new_session
    FROM new_col
)
SELECT
    *,
    SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY event_time) AS session_number
FROM step2;


-- Question 4: Day-1 Retention
-- retention_pct = retained users (active exactly signup_date + 1) / total users who signed up that day
WITH step1 AS (
    SELECT DISTINCT
        e.user_id AS e_id,
        u.user_id AS u_id,
        DATE(e.event_time) AS event_time,
        DATE(u.signup_date) AS signup_date,
        DATE(u.signup_date, '+1 day') AS tmr_date
    FROM events e
    LEFT JOIN users u ON e.user_id = u.user_id
    WHERE DATE(e.event_time) = DATE(u.signup_date, '+1 day')
),
step2 AS (
    SELECT signup_date, COUNT(u_id) AS retained_users
    FROM step1
    GROUP BY signup_date
),
total_signup AS (
    SELECT signup_date, COUNT(*) AS total_users
    FROM users
    GROUP BY signup_date
)
SELECT
    total_signup.signup_date,
    step2.retained_users,
    total_signup.total_users,
    (CAST(step2.retained_users AS REAL) / total_signup.total_users) * 100 AS retention_pct
FROM total_signup
LEFT JOIN step2 ON total_signup.signup_date = step2.signup_date;


-- Question 5: Inventory Drop Anomaly
-- Flag product/location where stock dropped more than 50% vs previous day's snapshot.
-- GROUP BY includes location_id (not just product_id + snapshot_date) so this stays
-- correct if a second location is ever added -- currently only one location (BKK) exists,
-- so this bug would not have shown up in this dataset.
SELECT
    product_id,
    location_id,
    snapshot_date,
    SUM(stock_qty) AS stock_qty,
    (((SUM(stock_qty) * 100) / (LAG(stock_qty) OVER (PARTITION BY product_id, location_id ORDER BY snapshot_date))) - 100) AS pct_diff,
    CASE
        WHEN (((SUM(stock_qty) * 100) / (LAG(stock_qty) OVER (PARTITION BY product_id, location_id ORDER BY snapshot_date))) - 100) < -50 THEN 'TRUE'
        ELSE 'FALSE'
    END AS lower_than_50_from_prev
FROM inventory_snapshot
GROUP BY snapshot_date, product_id, location_id
ORDER BY product_id, snapshot_date;


-- Question 9: Increasing Transactions
-- Adapted from the original PDF (no `transactions` table in practice.db) --
-- reuses the same double-LAG pattern on `orders` (customer_id, order_date, amount)
-- instead of (account_id, transaction_id, transaction_time, amount).
-- Flags orders that are the 3rd of a strictly increasing streak for that customer.
-- prev_2_amount IS NOT NULL doubles as an implicit "does this customer even have
-- 3 orders yet" check -- LAG(amount, 2) returns NULL when there aren't 2 prior rows,
-- and any comparison against NULL is never TRUE.
WITH step1 AS (
    SELECT
        *,
        LAG(amount, 1) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_amount,
        LAG(amount, 2) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_2_amount
    FROM orders
),
step2 AS (
    SELECT
        *,
        CASE
            WHEN prev_2_amount IS NOT NULL AND amount > prev_amount AND prev_amount > prev_2_amount THEN 'TRUE'
            ELSE 'FALSE'
        END AS is_increasing_streak
    FROM step1
)
SELECT * FROM step2 ORDER BY customer_id, order_date;
