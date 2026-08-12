-- =============================================================================
-- Table   : kbao_dim_geolocation
-- Layer   : Dimension
-- Grain   : 1 row per zip_code_prefix
-- Sources : kbao_olist_geolocation_dataset
-- Notes   :
--   * The raw geolocation feed holds many rows per zip prefix. Coordinates are
--     averaged to give one representative point per prefix for mapping.
--   * Known limitation: ANY_VALUE(city) is non-deterministic where a prefix
--     spans multiple city spellings. State is effectively stable at prefix
--     level, so state-level analysis is unaffected; city-level is not.
-- =============================================================================

SELECT
    geolocation_zip_code_prefix                         AS zip_code_prefix,
    AVG(geolocation_lat)                                AS lat,
    AVG(geolocation_lng)                                AS lng,
    ANY_VALUE(geolocation_city)                         AS city,
    ANY_VALUE(geolocation_state)                        AS state
FROM practice_data_pipeline.kbao_olist_geolocation_dataset
GROUP BY geolocation_zip_code_prefix;
