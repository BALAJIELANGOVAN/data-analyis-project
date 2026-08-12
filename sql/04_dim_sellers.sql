-- =============================================================================
-- Table   : kbao_dim_sellers
-- Layer   : Dimension
-- Grain   : 1 row per seller_id
-- Sources : kbao_olist_sellers_dataset
-- Notes   : Straight pass-through of the raw seller feed. Kept as its own build
--           step so the star schema has a single owned source for seller
--           attributes rather than joining raw tables from the BI layer.
-- =============================================================================

SELECT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM practice_data_pipeline.kbao_olist_sellers_dataset;
