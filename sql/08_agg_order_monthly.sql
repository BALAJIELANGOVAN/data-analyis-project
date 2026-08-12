-- =============================================================================
-- Table   : kbao_agg_order_monthly
-- Layer   : Aggregate
-- Grain   : 1 row per calendar month
-- Sources : kbao_fact_orders  (must be built first - see 06_fact_orders.sql)
--
-- Design notes:
--   * on_time_pct is deliberately scoped to delivered orders on both sides of
--     the ratio, because is_late returns 0 for orders that were never
--     delivered. Without that filter the rate would be overstated.
--   * month_start is kept alongside year_month so the table can join to
--     kbao_dim_date on a real DATE rather than a string.
--
-- Known limitation:
--   * avg_review is AVG(avg_review_score), i.e. an average of order-level
--     averages, not a review-weighted mean. Orders with several reviews are
--     under-weighted. Kept for trend shape; the review-weighted figure is
--     calculated in DAX for headline numbers.
-- =============================================================================

SELECT
    FORMAT_DATE('%Y-%m', DATE(order_purchase_timestamp))    AS year_month,
    DATE_TRUNC(DATE(order_purchase_timestamp), MONTH)       AS month_start,
    COUNT(*)                                                AS total_orders,
    COUNTIF(order_status = 'delivered')                     AS delivered_orders,
    COUNTIF(order_status = 'canceled')                      AS canceled_orders,
    SUM(total_order_value)                                  AS gmv,
    AVG(total_order_value)                                  AS avg_order_value,
    ROUND(SUM(CASE WHEN is_late = 0 AND order_status='delivered' THEN 1 ELSE 0 END)
          * 100.0 / NULLIF(COUNTIF(order_status='delivered'), 0), 2) AS on_time_pct,
    AVG(avg_review_score)                                   AS avg_review,
    COUNT(DISTINCT customer_unique_id)                      AS unique_customers
FROM `jda-k1.practice_data_pipeline.kbao_fact_orders`
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY year_month, month_start
ORDER BY year_month;
