-- dim_customers: unique customer_id ที่เคยสั่งซื้อ, ref จาก fact table (orders) ผ่าน customer_id
-- grain: 1 แถว = 1 customer

SELECT DISTINCT customer_id FROM orders;
