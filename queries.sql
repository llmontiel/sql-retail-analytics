-- queries.sql
-- A set of analytical queries against the retail star schema.
-- Each demonstrates a distinct SQL skill used in real analyst work.
-- All run on SQLite (which supports CTEs and window functions).

-- =========================================================================
-- Q1. Revenue by category and region  (basic star-schema join + rollup)
-- =========================================================================
SELECT
    p.category,
    s.region,
    ROUND(SUM(f.revenue), 2) AS revenue,
    SUM(f.units)             AS units
FROM fact_sales f
JOIN dim_product p ON p.product_key = f.product_key
JOIN dim_store   s ON s.store_key   = f.store_key
GROUP BY p.category, s.region
ORDER BY revenue DESC;


-- =========================================================================
-- Q2. Monthly revenue with MoM growth  (window LAG + period-over-period)
-- =========================================================================
WITH monthly AS (
    SELECT
        d.year,
        d.month,
        SUM(f.revenue) AS revenue
    FROM fact_sales f
    JOIN dim_date d ON d.date_key = f.date_key
    GROUP BY d.year, d.month
)
SELECT
    year,
    month,
    ROUND(revenue, 2) AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY year, month), 2) AS prev_month,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY year, month))
          / LAG(revenue) OVER (ORDER BY year, month), 1) AS mom_growth_pct
FROM monthly
ORDER BY year, month;


-- =========================================================================
-- Q3. Top 3 SKUs per category by revenue  (RANK within partition)
-- =========================================================================
WITH sku_rev AS (
    SELECT
        p.category,
        p.sku,
        SUM(f.revenue) AS revenue,
        RANK() OVER (PARTITION BY p.category ORDER BY SUM(f.revenue) DESC) AS rnk
    FROM fact_sales f
    JOIN dim_product p ON p.product_key = f.product_key
    GROUP BY p.category, p.sku
)
SELECT category, sku, ROUND(revenue, 2) AS revenue, rnk
FROM sku_rev
WHERE rnk <= 3
ORDER BY category, rnk;


-- =========================================================================
-- Q4. Running (cumulative) revenue by day  (window SUM with frame)
-- =========================================================================
WITH daily AS (
    SELECT d.full_date, SUM(f.revenue) AS revenue
    FROM fact_sales f
    JOIN dim_date d ON d.date_key = f.date_key
    GROUP BY d.full_date
)
SELECT
    full_date,
    ROUND(revenue, 2) AS daily_revenue,
    ROUND(SUM(revenue) OVER (ORDER BY full_date
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS cumulative_revenue
FROM daily
ORDER BY full_date
LIMIT 15;


-- =========================================================================
-- Q5. Promo lift  (conditional aggregation — promo vs non-promo AOV)
-- =========================================================================
SELECT
    p.category,
    ROUND(AVG(CASE WHEN f.on_promo = 1 THEN f.revenue END), 2) AS avg_promo_rev,
    ROUND(AVG(CASE WHEN f.on_promo = 0 THEN f.revenue END), 2) AS avg_base_rev,
    ROUND(
        100.0 * (AVG(CASE WHEN f.on_promo = 1 THEN f.revenue END)
               - AVG(CASE WHEN f.on_promo = 0 THEN f.revenue END))
        / AVG(CASE WHEN f.on_promo = 0 THEN f.revenue END), 1
    ) AS promo_lift_pct
FROM fact_sales f
JOIN dim_product p ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY promo_lift_pct DESC;


-- =========================================================================
-- Q6. Weekend vs weekday revenue share by region  (ratio of filtered sums)
-- =========================================================================
SELECT
    s.region,
    ROUND(SUM(CASE WHEN d.is_weekend = 1 THEN f.revenue ELSE 0 END), 2) AS weekend_rev,
    ROUND(SUM(CASE WHEN d.is_weekend = 0 THEN f.revenue ELSE 0 END), 2) AS weekday_rev,
    ROUND(100.0 * SUM(CASE WHEN d.is_weekend = 1 THEN f.revenue ELSE 0 END)
          / SUM(f.revenue), 1) AS weekend_share_pct
FROM fact_sales f
JOIN dim_date  d ON d.date_key  = f.date_key
JOIN dim_store s ON s.store_key = f.store_key
GROUP BY s.region
ORDER BY weekend_share_pct DESC;
