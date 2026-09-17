# Data Model

A small star schema: one fact table surrounded by one dimension table, extended with one serving table for downstream consumers (dashboards/analysts).

## Tables

| Table | Type | Grain | Source | Description |
|---|---|---|---|---|
| `orders` | Fact | 1 row = 1 order | `data/staging/orders_clean.csv` (loaded via `src/load_to_sqlite.py`) | Order data after dedup + validation by `clean_order.py` |
| `dim_customers` (view, `sql/dim_customers.sql`) | Dimension | 1 row = 1 customer | `orders.customer_id` | Unique customers who have placed an order, referenced from the fact table via `customer_id` |
| `daily_orders_summary` (view, `sql/serving_table.sql`) | Serving | 1 row = 1 day | `orders` (GROUP BY date from `created_at`) | Daily order totals for dashboards/reporting directly, without querying the raw fact table |

## Relationships

```
orders (fact, grain=order)
   |
   |-- ref by customer_id --> dim_customers (grain=customer)
   |
   |-- GROUP BY date(created_at) --> daily_orders_summary (grain=day, serving table)
```

## Why this design

- **Grain for each table is verified with a real SQL query**, not just documented as a design intent — see `sql/data_quality_checks.sql`:
  - Check #4: `orders` grain = 1 order/row (`COUNT(*) = COUNT(DISTINCT order_id)` → `12 = 12`)
  - Check #5: reconciliation between the fact table and the serving table (`SUM(amount)` must match on both sides → `24650.5 = 24650.5`)
- **The serving table is separate from the fact table** because consumers (e.g. a dashboard) shouldn't query the raw/fact table directly every time — the serving table is a pre-aggregated view that's faster to query and matches the grain the business actually needs (daily, not per-order).
- **`serving_table.sql` was verified to match `daily_summary.py` (the original Python version) exactly** on every row — proof that the SQL version is correct against logic that had already been verified.

## Known limitation

- SCD (Slowly Changing Dimension) isn't implemented — `dim_customers` only stores `customer_id`, with no other attributes (name, region, etc.) and no history tracking. If more attributes are added later, a choice needs to be made between SCD Type 1 (overwrite the old value) or Type 2 (keep every historical version), depending on the use case.
