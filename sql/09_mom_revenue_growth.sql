-- =============================================================================
-- Query   : mom_revenue_growth
-- Layer   : Analytical (read-only query over the aggregate layer)
-- Grain   : 1 row per calendar month
-- Sources : kbao_agg_order_monthly  (must be built first - see 08_agg_order_monthly.sql)
--
-- Purpose:
--   Month-over-month growth in GMV and order volume, calculated with LAG()
--   rather than a self-join. This query is read-only: it creates nothing and
--   changes nothing upstream. It is not the source of the month-over-month
--   chart on the dashboard, which is calculated in DAX against the same
--   aggregate; both apply the same 100-order floor.
--
-- Guards, and why each one is here:
--   * Non-consecutive months. kbao_agg_order_monthly has no row for a month
--     with no orders (November 2016 is absent), so the previous row is not
--     always the previous calendar month. DATE_DIFF between month_start and
--     LAG(month_start) must equal exactly 1 month or the growth is NULL,
--     rather than silently comparing across a gap.
--   * Low-volume months. September 2016 has 4 orders and September 2018 has
--     20. A percentage change off a base that small is arithmetically real and
--     analytically meaningless, so growth is NULL unless BOTH the current and
--     the previous month carry at least 100 orders. The threshold matches the
--     one used on the dashboard.
--   * Division by zero. SAFE_DIVIDE returns NULL instead of erroring if a
--     previous-month value is 0.
--
-- Note   : NULL here means "not calculable", not "zero growth". The three
--          reasons are distinguished in growth_status so a reader never has to
--          guess which one applied.
-- =============================================================================

WITH monthly AS (

    SELECT
        year_month,
        month_start,
        total_orders,
        gmv
    FROM `jda-k1.practice_data_pipeline.kbao_agg_order_monthly`

), with_previous AS (

    SELECT
        year_month,
        month_start,
        total_orders,
        gmv,
        LAG(month_start)  OVER (ORDER BY month_start) AS prev_month_start,
        LAG(total_orders) OVER (ORDER BY month_start) AS prev_total_orders,
        LAG(gmv)          OVER (ORDER BY month_start) AS prev_gmv
    FROM monthly

), flagged AS (

    SELECT
        *,
        -- TRUE only when the preceding row is the immediately preceding
        -- calendar month. NULL prev_month_start (the first row) yields NULL,
        -- which is handled explicitly below.
        DATE_DIFF(month_start, prev_month_start, MONTH) = 1 AS is_consecutive,
        (total_orders >= 100 AND prev_total_orders >= 100) AS has_volume
    FROM with_previous

)

SELECT
    year_month,
    month_start,
    total_orders,
    gmv,
    prev_month_start,
    prev_total_orders,
    prev_gmv,

    CASE
        WHEN prev_month_start IS NULL THEN 'no_prior_month'
        WHEN NOT is_consecutive        THEN 'gap_in_months'
        WHEN NOT has_volume            THEN 'below_100_order_floor'
        ELSE 'calculated'
    END                                                     AS growth_status,

    CASE
        WHEN is_consecutive AND has_volume
        THEN ROUND(SAFE_DIVIDE(gmv - prev_gmv, prev_gmv) * 100, 2)
        ELSE NULL
    END                                                     AS gmv_mom_growth_pct,

    CASE
        WHEN is_consecutive AND has_volume
        THEN ROUND(SAFE_DIVIDE(total_orders - prev_total_orders, prev_total_orders) * 100, 2)
        ELSE NULL
    END                                                     AS orders_mom_growth_pct,

    CASE
        WHEN is_consecutive AND has_volume
        THEN ROUND(gmv - prev_gmv, 2)
        ELSE NULL
    END                                                     AS gmv_mom_change

FROM flagged
ORDER BY month_start;
