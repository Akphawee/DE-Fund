-- dim_customers: unique customer_ids who have placed an order, referenced from the fact table (orders) via customer_id
-- grain: 1 row = 1 customer

SELECT DISTINCT customer_id FROM orders;
