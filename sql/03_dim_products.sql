-- =============================================================================
-- Table   : kbao_dim_products
-- Layer   : Dimension
-- Grain   : 1 row per product_id
-- Sources : kbao_olist_products_dataset
--           kbao_product_category_name_translation
-- Notes   :
--   * product_category falls back English -> Portuguese -> 'unknown', so the
--     column is never NULL and Power BI slicers stay clean.
--   * product_category_pt is kept for traceability back to the raw feed.
--   * product_volume_cm3 is NULL when any of the three dimensions is missing,
--     rather than defaulting to 0.
-- =============================================================================

SELECT
    p.product_id,
    COALESCE(t.product_category_name_english,
             p.product_category_name,
             'unknown')                                 AS product_category,
    p.product_category_name                             AS product_category_pt,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    CASE
        WHEN p.product_length_cm IS NOT NULL
         AND p.product_height_cm IS NOT NULL
         AND p.product_width_cm  IS NOT NULL
        THEN p.product_length_cm * p.product_height_cm * p.product_width_cm
    END                                                 AS product_volume_cm3
FROM practice_data_pipeline.kbao_olist_products_dataset AS p
LEFT JOIN practice_data_pipeline.kbao_product_category_name_translation AS t
    ON p.product_category_name = t.product_category_name;
