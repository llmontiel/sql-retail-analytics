# SQL Retail Analytics

A star-schema retail data warehouse and a set of analytical SQL queries that
answer real merchandising questions — revenue trends, top performers, promo
lift, and seasonality. Built to show the SQL that lives at the core of every
data-analyst role: dimensional modeling plus window functions, CTEs, and
conditional aggregation.

> Runs on fully synthetic data (no real or confidential information) and uses
> only Python's standard library — `sqlite3`, zero dependencies. Clone and run.

## What's inside

```
schema.sql   ->  build_db.py  ->  retail.db  ->  queries.sql
(star schema)   (loads data)     (SQLite DB)    (6 analytical queries)
```

- schema.sql — a textbook star schema: one `fact_sales` table surrounded by
  `dim_store`, `dim_product`, and `dim_date`, with surrogate keys and indexes.
- build_db.py — generates synthetic sales and loads the warehouse (7,196 fact
  rows across 5 stores, 8 SKUs, 180 days), then runs every query and prints results.
- queries.sql — six analytical queries, each demonstrating a distinct skill.

## The queries (and the skill each shows)

| # | Question | SQL technique |
|---|---|---|
| Q1 | Revenue by category & region | Star-schema joins + rollup |
| Q2 | Monthly revenue with MoM growth | `LAG()` window + period-over-period |
| Q3 | Top 3 SKUs per category | `RANK() OVER (PARTITION BY ...)` |
| Q4 | Running cumulative revenue | `SUM() OVER (... ROWS UNBOUNDED PRECEDING)` |
| Q5 | Promo lift by category | Conditional aggregation (`CASE` inside `AVG`) |
| Q6 | Weekend revenue share by region | Ratio of filtered sums |

## Sample verified output

```
Q3. Top 3 SKUs per category by revenue  (RANK within partition)
category   | sku              | revenue   | rnk
Beverage   | SKU_COLA_12PK    | 292832.07 | 1
Beverage   | SKU_WATER_24PK   | 232078.77 | 2
Candy      | SKU_GUMMIES      | 154434.78 | 1
Snacks     | SKU_CHIPS_FAMILY | 144202.59 | 1

Q5. Promo lift by category
category   | avg_promo_rev | avg_base_rev | promo_lift_pct
Candy      | 223.38        | 122.15       | 82.9
Beverage   | 480.25        | 270.95       | 77.2
```

## Quickstart

```bash
python build_db.py            # builds retail.db and runs all 6 queries
python build_db.py --rebuild  # drop and rebuild from scratch
```

No installs needed — `sqlite3` ships with Python. To explore interactively:

```bash
sqlite3 retail.db
sqlite> .read queries.sql
```

## Why it's built this way

- Star schema, not one flat table — surrogate keys (`store_key`, `product_key`,
  `date_key`) and conformed dimensions are how real warehouses are modeled. It
  makes joins fast and the grain explicit.
- A `dim_date` table — pre-computing `is_weekend`, `quarter`, `day_of_week` is
  standard practice; it keeps time-based filtering out of every query.
- Window functions over subquery gymnastics — `LAG`, `RANK`, and framed `SUM`
  express period-over-period, ranking, and running totals cleanly and readably.

## Repo structure

```
sql-retail-analytics/
├── schema.sql       # star-schema DDL
├── queries.sql      # 6 analytical queries
├── build_db.py      # loader + runner (stdlib only)
└── retail.db        # generated SQLite warehouse
```
