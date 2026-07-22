\pset pager off

DROP TABLE IF EXISTS analytics.shipment_summary;

CREATE TABLE analytics.shipment_summary AS

WITH grouped_shipments AS (
    SELECT
        asn_dn_number AS shipment_id,

        MIN(po_so_number) AS po_so_number,
        MIN(country) AS country,
        MIN(vendor) AS vendor,
        MIN(shipment_mode) AS shipment_mode,

        COUNT(*) AS line_item_count,

        COUNT(DISTINCT scheduled_delivery_date)
            AS scheduled_date_count,

        CASE
            WHEN COUNT(DISTINCT scheduled_delivery_date) = 1
            THEN MIN(scheduled_delivery_date)
        END AS scheduled_delivery_date,

        MIN(delivered_to_client_date)
            AS delivered_to_client_date,

        SUM(line_item_value_usd)
            AS total_line_item_value_usd,

        MAX(freight_cost_usd)
            AS freight_cost_usd,

        COUNT(freight_cost_usd)
            AS numeric_freight_rows

    FROM analytics.shipments
    GROUP BY asn_dn_number
)

SELECT
    *,

    delivered_to_client_date
        - scheduled_delivery_date AS delay_days,

    CASE
        WHEN scheduled_delivery_date IS NULL
          OR delivered_to_client_date IS NULL
            THEN 'unknown'

        WHEN delivered_to_client_date
             < scheduled_delivery_date
            THEN 'early'

        WHEN delivered_to_client_date
             = scheduled_delivery_date
            THEN 'on_time'

        ELSE 'late'
    END AS delivery_status,

    CASE
        WHEN scheduled_delivery_date IS NULL
          OR delivered_to_client_date IS NULL
            THEN NULL

        ELSE delivered_to_client_date
             <= scheduled_delivery_date
    END AS is_on_time,

    CASE
        WHEN freight_cost_usd IS NOT NULL
          AND total_line_item_value_usd > 0
        THEN freight_cost_usd
             / total_line_item_value_usd
    END AS freight_cost_ratio

FROM grouped_shipments;

CREATE UNIQUE INDEX idx_shipment_summary_id
    ON analytics.shipment_summary(shipment_id);

-- Confirm the shipment-level structure
SELECT
    COUNT(*) AS total_shipments,
    SUM(line_item_count) AS original_line_item_records,

    COUNT(freight_cost_usd)
        AS shipments_with_numeric_freight,

    COUNT(*) FILTER (
        WHERE numeric_freight_rows > 1
    ) AS shipments_with_multiple_numeric_freight_rows,

    COUNT(*) FILTER (
        WHERE scheduled_date_count > 1
    ) AS shipments_with_inconsistent_scheduled_dates

FROM analytics.shipment_summary;

-- Better freight metrics
SELECT
    ROUND(
        100
        * SUM(freight_cost_usd) FILTER (
            WHERE freight_cost_usd IS NOT NULL
              AND total_line_item_value_usd > 0
        )
        / NULLIF(
            SUM(total_line_item_value_usd) FILTER (
                WHERE freight_cost_usd IS NOT NULL
                  AND total_line_item_value_usd > 0
            ),
            0
        ),
        2
    ) AS weighted_freight_ratio_pct,

    ROUND(
        (
            100 * PERCENTILE_CONT(0.5)
            WITHIN GROUP (
                ORDER BY freight_cost_ratio
            )
            FILTER (
                WHERE freight_cost_ratio IS NOT NULL
            )
        )::numeric,
        2
    ) AS median_shipment_freight_ratio_pct,

    COUNT(*) FILTER (
        WHERE freight_cost_ratio > 1
    ) AS shipments_where_freight_exceeds_value

FROM analytics.shipment_summary;
