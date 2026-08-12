-- =============================================================================
-- Table   : kbao_dim_date
-- Layer   : Dimension
-- Grain   : 1 row per calendar date
-- Sources : none (generated)
-- Range   : 2016-01-01 to 2018-12-31 (covers the Olist order window with buffer)
-- Notes   : day_of_week follows BigQuery convention (1 = Sunday ... 7 = Saturday),
--           so is_weekend flags DAYOFWEEK IN (1, 7).
-- =============================================================================

SELECT
    date_value                                          AS date,
    EXTRACT(YEAR    FROM date_value)                    AS year,
    EXTRACT(QUARTER FROM date_value)                    AS quarter,
    EXTRACT(MONTH   FROM date_value)                    AS month,
    FORMAT_DATE('%b', date_value)                       AS month_short_name,
    FORMAT_DATE('%B', date_value)                       AS month_name,
    EXTRACT(WEEK    FROM date_value)                    AS week_of_year,
    EXTRACT(DAY     FROM date_value)                    AS day_of_month,
    EXTRACT(DAYOFWEEK FROM date_value)                  AS day_of_week,
    FORMAT_DATE('%A', date_value)                       AS day_name,
    (EXTRACT(DAYOFWEEK FROM date_value) IN (1, 7))      AS is_weekend,
    FORMAT_DATE('%Y-%m', date_value)                    AS year_month
FROM UNNEST(
    GENERATE_DATE_ARRAY(DATE '2016-01-01', DATE '2018-12-31', INTERVAL 1 DAY)
) AS date_value;
