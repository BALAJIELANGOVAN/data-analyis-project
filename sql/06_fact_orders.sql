-- =============================================================================
-- Table   : kbao_fact_orders
-- Layer   : Fact (order grain)
-- Grain   : 1 row per order_id
-- Sources : kbao_olist_orders_dataset            (spine)
--           kbao_olist_customers_dataset         (customer attributes)
--           kbao_olist_order_reviews_dataset     -> review_agg
--           kbao_olist_order_payments_dataset    -> payment_agg
--           kbao_olist_order_items_dataset       -> item_agg
--
-- Design notes:
--   * Reviews, payments and items are each pre-aggregated to order grain in a
--     CTE BEFORE joining. Joining them directly would fan the order spine out
--     and double-count GMV.
--   * Delivery timings are split into three stages (approve -> carrier handoff
--     -> shipping) so a delay can be attributed to a stage, not just measured
--     end to end. GREATEST(..., 0) + NULLIF suppress negative/zero artefacts
--     from out-of-order timestamps.
--   * delay_bucket is prefixed 1_..6_ so it sorts correctly in Power BI without
--     a separate sort-by column.
--   * WHERE clause drops orders marked 'delivered' with no delivery timestamp
--     (contradictory records that would distort on-time rate).
--
-- Known limitation:
--   * is_late returns 0 (not NULL) for orders that were never delivered. Any
--     on-time rate must therefore be filtered to order_status = 'delivered',
--     as done in 08_agg_order_monthly.sql, or it will be overstated.
-- =============================================================================

WITH
review_agg AS (
    SELECT
        order_id,
        AVG(review_score)                               AS avg_review_score,
        COUNT(*)                                        AS review_count
    FROM `jda-k1.practice_data_pipeline.kbao_olist_order_reviews_dataset`
    GROUP BY order_id
),
payment_agg AS (
    SELECT
        order_id,
        SUM(payment_value)                              AS total_payment_value,
        COUNT(*)                                        AS payment_count,
        MAX(payment_installments)                       AS max_installments,
        STRING_AGG(DISTINCT payment_type ORDER BY payment_type) AS payment_types
    FROM `jda-k1.practice_data_pipeline.kbao_olist_order_payments_dataset`
    GROUP BY order_id
),
item_agg AS (
    SELECT
        order_id,
        COUNT(*)                                        AS item_count,
        COUNT(DISTINCT product_id)                      AS unique_product_count,
        COUNT(DISTINCT seller_id)                       AS unique_seller_count,
        SUM(price)                                      AS total_items_price,
        SUM(freight_value)                              AS total_freight,
        SUM(price + freight_value)                      AS total_order_value
    FROM `jda-k1.practice_data_pipeline.kbao_olist_order_items_dataset`
    GROUP BY order_id
)

SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    c.customer_city,
    o.order_status,

    CAST(o.order_purchase_timestamp        AS TIMESTAMP)        AS order_purchase_timestamp,
    CAST(o.order_approved_at               AS TIMESTAMP)        AS order_approved_at,
    CAST(o.order_delivered_carrier_date    AS TIMESTAMP)        AS order_delivered_carrier_date,
    CAST(o.order_delivered_customer_date   AS TIMESTAMP)        AS order_delivered_customer_date,
    DATE(CAST(o.order_estimated_delivery_date AS TIMESTAMP))    AS order_estimated_delivery_date,
    DATE(CAST(o.order_purchase_timestamp AS TIMESTAMP))         AS purchase_date,

    CASE
        WHEN o.order_status = 'delivered'
         AND o.order_delivered_customer_date IS NOT NULL
        THEN DATE_DIFF(
            DATE(CAST(o.order_delivered_customer_date AS TIMESTAMP)),
            DATE(CAST(o.order_purchase_timestamp AS TIMESTAMP)),
            DAY
        )
    END                                                 AS days_to_deliver_actual,

    DATE_DIFF(
        DATE(CAST(o.order_estimated_delivery_date AS TIMESTAMP)),
        DATE(CAST(o.order_purchase_timestamp AS TIMESTAMP)),
        DAY
    )                                                   AS days_promised,

    CASE
        WHEN o.order_status = 'delivered'
         AND o.order_delivered_customer_date IS NOT NULL
        THEN DATE_DIFF(
            DATE(CAST(o.order_delivered_customer_date AS TIMESTAMP)),
            DATE(CAST(o.order_estimated_delivery_date AS TIMESTAMP)),
            DAY
        )
    END                                                 AS delay_days,

    CASE
        WHEN o.order_status = 'delivered'
         AND o.order_delivered_customer_date IS NOT NULL
         AND DATE(CAST(o.order_delivered_customer_date AS TIMESTAMP))
             > DATE(CAST(o.order_estimated_delivery_date AS TIMESTAMP))
        THEN 1 ELSE 0
    END                                                 AS is_late,

    CASE
        WHEN o.order_status != 'delivered' OR o.order_delivered_customer_date IS NULL
            THEN 'not_delivered'
        WHEN DATE_DIFF(DATE(CAST(o.order_delivered_customer_date AS TIMESTAMP)),
                       DATE(CAST(o.order_estimated_delivery_date AS TIMESTAMP)), DAY) <= -7
            THEN '1_early_7plus_days'
        WHEN DATE_DIFF(DATE(CAST(o.order_delivered_customer_date AS TIMESTAMP)),
                       DATE(CAST(o.order_estimated_delivery_date AS TIMESTAMP)), DAY) < 0
            THEN '2_early_1to6_days'
        WHEN DATE_DIFF(DATE(CAST(o.order_delivered_customer_date AS TIMESTAMP)),
                       DATE(CAST(o.order_estimated_delivery_date AS TIMESTAMP)), DAY) = 0
            THEN '3_on_time'
        WHEN DATE_DIFF(DATE(CAST(o.order_delivered_customer_date AS TIMESTAMP)),
                       DATE(CAST(o.order_estimated_delivery_date AS TIMESTAMP)), DAY) <= 3
            THEN '4_slightly_late_1to3_days'
        WHEN DATE_DIFF(DATE(CAST(o.order_delivered_customer_date AS TIMESTAMP)),
                       DATE(CAST(o.order_estimated_delivery_date AS TIMESTAMP)), DAY) <= 14
            THEN '5_late_4to14_days'
        ELSE '6_very_late_15plus_days'
    END                                                 AS delay_bucket,

    NULLIF(GREATEST(
        TIMESTAMP_DIFF(CAST(o.order_approved_at AS TIMESTAMP),
                       CAST(o.order_purchase_timestamp AS TIMESTAMP), HOUR), 0
    ), 0)                                               AS approve_stage_hours,

    NULLIF(GREATEST(
        TIMESTAMP_DIFF(CAST(o.order_delivered_carrier_date AS TIMESTAMP),
                       CAST(o.order_approved_at AS TIMESTAMP), HOUR), 0
    ), 0)                                               AS carrier_handoff_stage_hours,

    NULLIF(GREATEST(
        TIMESTAMP_DIFF(CAST(o.order_delivered_customer_date AS TIMESTAMP),
                       CAST(o.order_delivered_carrier_date AS TIMESTAMP), HOUR), 0
    ), 0)                                               AS shipping_stage_hours,

    TIMESTAMP_DIFF(
        CAST(o.order_delivered_customer_date AS TIMESTAMP),
        CAST(o.order_purchase_timestamp AS TIMESTAMP),
        HOUR
    )                                                   AS total_delivery_hours,

    r.avg_review_score,
    r.review_count,

    p.total_payment_value,
    p.payment_count,
    p.max_installments,
    p.payment_types,

    i.item_count,
    i.unique_product_count,
    i.unique_seller_count,
    i.total_items_price,
    i.total_freight,
    i.total_order_value

FROM `jda-k1.practice_data_pipeline.kbao_olist_orders_dataset` AS o
LEFT JOIN `jda-k1.practice_data_pipeline.kbao_olist_customers_dataset` AS c
    ON o.customer_id = c.customer_id
LEFT JOIN review_agg  AS r ON o.order_id = r.order_id
LEFT JOIN payment_agg AS p ON o.order_id = p.order_id
LEFT JOIN item_agg    AS i ON o.order_id = i.order_id
WHERE NOT (
    o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NULL
);
