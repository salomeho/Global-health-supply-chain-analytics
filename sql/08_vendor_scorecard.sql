\pset pager off

DROP VIEW IF EXISTS analytics.vendor_scorecard;

CREATE VIEW analytics.vendor_scorecard AS

WITH vendor_metrics AS (
    SELECT
        vendor,

        COUNT(*) AS total_shipments,

        COUNT(*) FILTER (
            WHERE scheduled_date_count = 1
              AND scheduled_delivery_date IS NOT NULL
              AND delivered_to_client_date IS NOT NULL
        ) AS valid_delivery_shipments,

        COUNT(*) FILTER (
            WHERE scheduled_date_count = 1
              AND delivery_status = 'late'
        ) AS late_shipments,

        AVG(is_on_time::integer) FILTER (
            WHERE scheduled_date_count = 1
              AND scheduled_delivery_date IS NOT NULL
              AND delivered_to_client_date IS NOT NULL
        ) AS on_time_rate,

        AVG(delay_days) FILTER (
            WHERE scheduled_date_count = 1
              AND delivery_status = 'late'
        ) AS average_days_late,

        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY delay_days)
        FILTER (
            WHERE scheduled_date_count = 1
              AND delivery_status = 'late'
        ) AS median_days_late,

        COUNT(*) FILTER (
            WHERE freight_cost_usd IS NOT NULL
              AND total_line_item_value_usd > 0
        ) AS shipments_with_numeric_freight,

        SUM(freight_cost_usd) FILTER (
            WHERE freight_cost_usd IS NOT NULL
              AND total_line_item_value_usd > 0
        )
        /
        NULLIF(
            SUM(total_line_item_value_usd) FILTER (
                WHERE freight_cost_usd IS NOT NULL
                  AND total_line_item_value_usd > 0
            ),
            0
        ) AS weighted_freight_ratio

    FROM analytics.shipment_summary

    WHERE vendor IS NOT NULL

    GROUP BY vendor
),

eligible_vendors AS (
    SELECT *
    FROM vendor_metrics
    WHERE valid_delivery_shipments >= 20
),

ranked_vendors AS (
    SELECT
        *,

        DENSE_RANK() OVER (
            ORDER BY on_time_rate ASC
        ) AS reliability_risk_rank,

        NTILE(4) OVER (
            ORDER BY on_time_rate ASC
        ) AS reliability_quartile,

        DENSE_RANK() OVER (
            ORDER BY total_shipments DESC
        ) AS shipment_volume_rank,

        DENSE_RANK() OVER (
            ORDER BY weighted_freight_ratio DESC NULLS LAST
        ) AS freight_cost_rank,

        SUM(total_shipments) OVER ()
            AS eligible_vendor_shipments

    FROM eligible_vendors
)

SELECT
    vendor,
    total_shipments,
    valid_delivery_shipments,
    late_shipments,

    ROUND(
        100 * on_time_rate,
        2
    ) AS on_time_rate_pct,

    ROUND(
        average_days_late,
        2
    ) AS average_days_late,

    ROUND(
        median_days_late::numeric,
        2
    ) AS median_days_late,

    shipments_with_numeric_freight,

    ROUND(
        100.0 * shipments_with_numeric_freight
        / NULLIF(total_shipments, 0),
        2
    ) AS freight_data_coverage_pct,

    ROUND(
        100 * weighted_freight_ratio,
        2
    ) AS weighted_freight_ratio_pct,

    ROUND(
        100.0 * total_shipments
        / NULLIF(eligible_vendor_shipments, 0),
        2
    ) AS shipment_share_pct,

    reliability_risk_rank,
    reliability_quartile,
    shipment_volume_rank,
    freight_cost_rank,

    CASE
        WHEN reliability_quartile = 1
         AND total_shipments >= 50
            THEN 'Urgent reliability review'

        WHEN reliability_quartile = 1
            THEN 'Reliability review'

        WHEN reliability_quartile = 4
         AND total_shipments >= 50
            THEN 'Reliable benchmark'

        ELSE 'Monitor'
    END AS review_category

FROM ranked_vendors;


-- Number of vendors with enough data
SELECT
    COUNT(*) AS eligible_vendors
FROM analytics.vendor_scorecard;


-- Vendors management should review first
SELECT
    vendor,
    total_shipments,
    late_shipments,
    on_time_rate_pct,
    average_days_late,
    weighted_freight_ratio_pct,
    freight_data_coverage_pct,
    reliability_risk_rank,
    shipment_volume_rank,
    review_category
FROM analytics.vendor_scorecard
WHERE review_category IN (
    'Urgent reliability review',
    'Reliability review'
)
ORDER BY
    reliability_risk_rank,
    total_shipments DESC
LIMIT 20;
