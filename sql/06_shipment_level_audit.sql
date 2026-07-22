\pset pager off

-- =========================================================
-- 1. Check whether shipment-level fields are consistent
-- =========================================================

WITH shipment_consistency AS (
    SELECT
        asn_dn_number AS shipment_id,

        COUNT(DISTINCT country)
            AS country_count,

        COUNT(DISTINCT vendor)
            AS vendor_count,

        COUNT(
            DISTINCT COALESCE(shipment_mode, '[missing]')
        ) AS shipment_mode_count,

        COUNT(DISTINCT scheduled_delivery_date)
            AS scheduled_date_count,

        COUNT(DISTINCT delivered_to_client_date)
            AS delivered_date_count

    FROM analytics.shipments
    GROUP BY asn_dn_number
)

SELECT
    COUNT(*) AS total_shipments,

    COUNT(*) FILTER (
        WHERE country_count > 1
    ) AS inconsistent_country,

    COUNT(*) FILTER (
        WHERE vendor_count > 1
    ) AS inconsistent_vendor,

    COUNT(*) FILTER (
        WHERE shipment_mode_count > 1
    ) AS inconsistent_shipment_mode,

    COUNT(*) FILTER (
        WHERE scheduled_date_count > 1
    ) AS inconsistent_scheduled_date,

    COUNT(*) FILTER (
        WHERE delivered_date_count > 1
    ) AS inconsistent_delivered_date

FROM shipment_consistency;


-- =========================================================
-- 2. Inspect shipments with multiple scheduled dates
-- =========================================================

SELECT
    shipment_id,
    country,
    vendor,
    shipment_mode,
    line_item_count,
    scheduled_date_count,
    total_line_item_value_usd,
    freight_cost_usd

FROM analytics.shipment_summary

WHERE scheduled_date_count > 1

ORDER BY line_item_count DESC,
         shipment_id;


-- =========================================================
-- 3. Freight-ratio distribution
-- =========================================================

SELECT
    ROUND(
        (
            100 * PERCENTILE_CONT(0.50)
            WITHIN GROUP (ORDER BY freight_cost_ratio)
        )::numeric,
        2
    ) AS p50_freight_ratio_pct,

    ROUND(
        (
            100 * PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY freight_cost_ratio)
        )::numeric,
        2
    ) AS p75_freight_ratio_pct,

    ROUND(
        (
            100 * PERCENTILE_CONT(0.90)
            WITHIN GROUP (ORDER BY freight_cost_ratio)
        )::numeric,
        2
    ) AS p90_freight_ratio_pct,

    ROUND(
        (
            100 * PERCENTILE_CONT(0.95)
            WITHIN GROUP (ORDER BY freight_cost_ratio)
        )::numeric,
        2
    ) AS p95_freight_ratio_pct,

    ROUND(
        (
            100 * PERCENTILE_CONT(0.99)
            WITHIN GROUP (ORDER BY freight_cost_ratio)
        )::numeric,
        2
    ) AS p99_freight_ratio_pct

FROM analytics.shipment_summary

WHERE freight_cost_ratio IS NOT NULL;


-- =========================================================
-- 4. Understand freight-cost outliers
-- =========================================================

SELECT
    COUNT(*) FILTER (
        WHERE freight_cost_ratio > 1
    ) AS freight_exceeds_value,

    COUNT(*) FILTER (
        WHERE freight_cost_ratio > 1
          AND total_line_item_value_usd < 100
    ) AS exceeds_value_and_item_value_under_100,

    COUNT(*) FILTER (
        WHERE freight_cost_ratio > 1
          AND total_line_item_value_usd < 1000
    ) AS exceeds_value_and_item_value_under_1000

FROM analytics.shipment_summary;


-- =========================================================
-- 5. View the largest freight ratios
-- =========================================================

SELECT
    shipment_id,
    country,
    vendor,
    shipment_mode,
    line_item_count,

    ROUND(
        total_line_item_value_usd,
        2
    ) AS commodity_value_usd,

    ROUND(
        freight_cost_usd,
        2
    ) AS freight_cost_usd,

    ROUND(
        100 * freight_cost_ratio,
        2
    ) AS freight_ratio_pct

FROM analytics.shipment_summary

WHERE freight_cost_ratio IS NOT NULL

ORDER BY freight_cost_ratio DESC

LIMIT 15;
