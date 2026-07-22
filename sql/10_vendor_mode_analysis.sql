\pset pager off

DROP VIEW IF EXISTS analytics.vendor_mode_scorecard;

CREATE VIEW analytics.vendor_mode_scorecard AS

WITH vendor_mode_metrics AS (
    SELECT
        vendor,

        CASE
            WHEN vendor = 'SCMS from RDC'
                THEN 'Internal distribution source'
            ELSE 'External vendor'
        END AS vendor_type,

        COALESCE(shipment_mode, 'Unknown') AS shipment_mode,

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

    GROUP BY
        vendor,
        COALESCE(shipment_mode, 'Unknown')
),

eligible_combinations AS (
    SELECT *
    FROM vendor_mode_metrics
    WHERE valid_delivery_shipments >= 20
),

ranked_combinations AS (
    SELECT
        *,

        DENSE_RANK() OVER (
            ORDER BY on_time_rate ASC
        ) AS overall_risk_rank,

        DENSE_RANK() OVER (
            PARTITION BY vendor
            ORDER BY on_time_rate DESC
        ) AS mode_reliability_rank_within_vendor,

        DENSE_RANK() OVER (
            PARTITION BY vendor
            ORDER BY weighted_freight_ratio ASC NULLS LAST
        ) AS mode_cost_rank_within_vendor

    FROM eligible_combinations
)

SELECT
    vendor,
    vendor_type,
    shipment_mode,
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

    overall_risk_rank,
    mode_reliability_rank_within_vendor,
    mode_cost_rank_within_vendor,

    CASE
        WHEN vendor = 'SCMS from RDC'
         AND on_time_rate < 0.90
            THEN 'Review internal route'

        WHEN total_shipments >= 50
         AND on_time_rate < 0.85
            THEN 'Urgent vendor-mode review'

        WHEN on_time_rate < 0.90
            THEN 'Vendor-mode review'

        WHEN total_shipments >= 50
         AND on_time_rate >= 0.95
            THEN 'Strong vendor-mode combination'

        ELSE 'Monitor'
    END AS review_category

FROM ranked_combinations;


SELECT
    vendor,
    shipment_mode,
    total_shipments,
    late_shipments,
    on_time_rate_pct,
    average_days_late,
    weighted_freight_ratio_pct,
    mode_reliability_rank_within_vendor,
    review_category
FROM analytics.vendor_mode_scorecard
ORDER BY
    CASE review_category
        WHEN 'Urgent vendor-mode review' THEN 1
        WHEN 'Vendor-mode review' THEN 2
        WHEN 'Review internal route' THEN 3
        WHEN 'Monitor' THEN 4
        WHEN 'Strong vendor-mode combination' THEN 5
    END,
    on_time_rate_pct,
    total_shipments DESC;
