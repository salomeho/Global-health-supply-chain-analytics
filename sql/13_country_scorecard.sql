\pset pager off

DROP VIEW IF EXISTS analytics.country_scorecard;

CREATE VIEW analytics.country_scorecard AS

WITH country_metrics AS (
    SELECT
        country,

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

        COUNT(DISTINCT vendor) AS vendor_count,

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

    WHERE country IS NOT NULL

    GROUP BY country
),

eligible_countries AS (
    SELECT *
    FROM country_metrics
    WHERE valid_delivery_shipments >= 30
),

ranked_countries AS (
    SELECT
        *,

        DENSE_RANK() OVER (
            ORDER BY on_time_rate ASC
        ) AS reliability_risk_rank,

        DENSE_RANK() OVER (
            ORDER BY total_shipments DESC
        ) AS shipment_volume_rank

    FROM eligible_countries
)

SELECT
    country,
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

    vendor_count,
    shipments_with_numeric_freight,

    ROUND(
        100 * weighted_freight_ratio,
        2
    ) AS weighted_freight_ratio_pct,

    reliability_risk_rank,
    shipment_volume_rank,

    CASE
        WHEN total_shipments >= 100
         AND on_time_rate < 0.85
            THEN 'High-priority destination review'

        WHEN on_time_rate < 0.90
            THEN 'Destination review'

        WHEN total_shipments >= 100
         AND on_time_rate >= 0.95
            THEN 'Reliable destination benchmark'

        ELSE 'Monitor'
    END AS review_category

FROM ranked_countries;


SELECT
    country,
    total_shipments,
    late_shipments,
    on_time_rate_pct,
    average_days_late,
    vendor_count,
    weighted_freight_ratio_pct,
    review_category
FROM analytics.country_scorecard
ORDER BY
    CASE review_category
        WHEN 'High-priority destination review' THEN 1
        WHEN 'Destination review' THEN 2
        WHEN 'Monitor' THEN 3
        WHEN 'Reliable destination benchmark' THEN 4
    END,
    on_time_rate_pct,
    total_shipments DESC;
