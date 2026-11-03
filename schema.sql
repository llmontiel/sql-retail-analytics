-- schema.sql
-- Star-schema warehouse for retail sales analytics.
-- One fact table (sales) + three dimensions (store, product, date).
-- Written for SQLite so the project runs anywhere with zero setup,
-- but the modeling (surrogate keys, star schema) is warehouse-standard.

DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_store;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_date;

-- ---------- Dimensions ----------
CREATE TABLE dim_store (
    store_key     INTEGER PRIMARY KEY,
    store_id      TEXT    NOT NULL UNIQUE,
    region        TEXT    NOT NULL,
    market        TEXT    NOT NULL
);

CREATE TABLE dim_product (
    product_key   INTEGER PRIMARY KEY,
    sku           TEXT    NOT NULL UNIQUE,
    category      TEXT    NOT NULL,
    unit_price    REAL    NOT NULL
);

CREATE TABLE dim_date (
    date_key      INTEGER PRIMARY KEY,   -- YYYYMMDD
    full_date     TEXT    NOT NULL,
    year          INTEGER NOT NULL,
    quarter       INTEGER NOT NULL,
    month         INTEGER NOT NULL,
    day_of_week   INTEGER NOT NULL,      -- 0=Mon
    is_weekend    INTEGER NOT NULL
);

-- ---------- Fact ----------
CREATE TABLE fact_sales (
    sale_id       INTEGER PRIMARY KEY,
    date_key      INTEGER NOT NULL REFERENCES dim_date(date_key),
    store_key     INTEGER NOT NULL REFERENCES dim_store(store_key),
    product_key   INTEGER NOT NULL REFERENCES dim_product(product_key),
    units         INTEGER NOT NULL,
    revenue       REAL    NOT NULL,
    on_promo      INTEGER NOT NULL
);

-- Indexes that matter for the analytical queries below
CREATE INDEX idx_fact_date    ON fact_sales(date_key);
CREATE INDEX idx_fact_store   ON fact_sales(store_key);
CREATE INDEX idx_fact_product ON fact_sales(product_key);
