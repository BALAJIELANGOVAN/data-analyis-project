-- =============================================================================
-- Table   : kbao_dim_customers
-- Layer   : Dimension
-- Grain   : 1 row per customer_unique_id (the true person-level key)
-- Sources : kbao_olist_customers_dataset
--           kbao_olist_orders_dataset
--           kbao_olist_order_items_dataset
-- Notes   :
--   * Olist ships two customer keys: customer_id is order-scoped (a new value per
--     order), customer_unique_id is person-level. This dimension is built on
--     customer_unique_id so repeat-purchase logic is correct.
--   * Known limitation: lifetime_value sums item price + freight across ALL
--     orders, including canceled/unavailable ones, so it slightly overstates
--     realised revenue.
--   * Known limitation: ANY_VALUE() on city/state/zip is non-deterministic when
--     a customer_unique_id appears with more than one address. Low impact for
--     state-level analysis, higher for city-level.
-- =============================================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        ANY_VALUE(c.customer_zip_code_prefix)           AS customer_zip_code_prefix,
        ANY_VALUE(c.customer_city)                      AS customer_city,
        ANY_VALUE(c.customer_state)                     AS customer_state,
        COUNT(DISTINCT o.order_id)                      AS total_orders,
        MIN(DATE(o.order_purchase_timestamp))           AS first_order_date,
        MAX(DATE(o.order_purchase_timestamp))           AS last_order_date,
        SUM(i.price + i.freight_value)                  AS lifetime_value
    FROM practice_data_pipeline.kbao_olist_customers_dataset c
    LEFT JOIN practice_data_pipeline.kbao_olist_orders_dataset o
        ON c.customer_id = o.customer_id
    LEFT JOIN practice_data_pipeline.kbao_olist_order_items_dataset i
        ON o.order_id = i.order_id
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    total_orders,
    first_order_date,
    last_order_date,
    lifetime_value,
    CASE WHEN total_orders > 1 THEN 1 ELSE 0 END        AS is_repeat_customer
FROM customer_orders;
