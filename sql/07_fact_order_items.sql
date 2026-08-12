-- =============================================================================
-- Table   : kbao_fact_order_items
-- Layer   : Fact (line-item grain)
-- Grain   : 1 row per (order_id, order_item_id)
-- Sources : kbao_olist_order_items_dataset       (spine)
--           kbao_olist_products_dataset          (category)
--           kbao_product_category_name_translation
--           kbao_olist_sellers_dataset           (seller location)
--
-- Design notes:
--   * This is the finer of the two fact tables. Order-level KPIs live in
--     kbao_fact_orders; anything sliced by product or seller comes from here.
--   * product_category and seller_state/city are denormalised onto the fact so
--     the most common slices do not need a dimension hop.
--
-- Known limitation:
--   * A small number of rows reference order_ids that were filtered out of
--     kbao_fact_orders (contradictory 'delivered' records), so they behave as
--     orphans against the order fact. Counted and documented rather than
--     silently dropped.
--   * The relationship between this table and kbao_fact_orders is inactive in
--     the Power BI model; TREATAS is used to bridge it when cross-filtering
--     from product/seller to order-grain measures.
-- =============================================================================

SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    CAST(i.shipping_limit_date AS TIMESTAMP)            AS shipping_limit_date,
    i.price,
    i.freight_value,
    i.price + i.freight_value                           AS total_item_value,
    COALESCE(t.product_category_name_english,
             p.product_category_name,
             'unknown')                                 AS product_category,
    s.seller_state,
    s.seller_city
FROM practice_data_pipeline.kbao_olist_order_items_dataset i
LEFT JOIN practice_data_pipeline.kbao_olist_products_dataset p
    ON i.product_id = p.product_id
LEFT JOIN practice_data_pipeline.kbao_product_category_name_translation t
    ON p.product_category_name = t.product_category_name
LEFT JOIN practice_data_pipeline.kbao_olist_sellers_dataset s
    ON i.seller_id = s.seller_id;
