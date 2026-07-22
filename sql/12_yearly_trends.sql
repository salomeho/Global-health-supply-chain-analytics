\pset pager off

DROP VIEW IF EXISTS analytics.yearly_mode_trends;
DROP VIEW IF EXISTS analytics.yearly_overall_trends;


-- =========================================================
-- 1. Overall yearly performance
-- =========================================================

CREATE VIEW analytics.yearly_overall_trends AS

WITH yearly_metrics AS (
    SELECT
        EXTRACT(
            YEAR FROM delivered_to_client_date
        )::integer AS delivery_year,

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

    WHERE delivered_to_client_date IS NOT NULL

    GROUP BY
        EXTRACT(YEAR FROM delivered_to_client_date)
),

with_previous_year AS (
    SELECT
        *,

        LAG(on_time_rate) OVER (
            ORDER BY delivery_year
        ) AS previous_year_on_time_rate

    FROM yearly_metrics
)

SELECT
    delivery_year,
    valid_delivery_shipments,
    late_shipments,

    ROUND(
        100 * on_time_rate,
        2
    ) AS on_time_rate_pct,

    ROUND(
        100 * (
            on_time_rate - previous_year_on_time_rate
        ),
        2
    ) AS year_over_year_change_pp,

    ROUND(
        average_days_late,
        2
    ) AS average_days_late,

    ROUND(
        100 * weighted_freight_ratio,
        2
    ) AS weighted_freight_ratio_pct

FROM with_previous_year;


-- =========================================================
-- 2. Yearly performance by shipment mode
-- =========================================================

CREATE VIEW analytics.yearly_mode_trends AS

WITH yearly_mode_metrics AS (
    SELECT
        EXTRACT(
            YEAR FROM delivered_to_client_date
        )::integer AS delivery_year,

        COALESCE(
            shipment_mode,
            'Unknown'
        ) AS shipment_mode,

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

    WHERE delivered_to_client_date IS NOT NULL

    GROUP BY
        EXTRACT(YEAR FROM delivered_to_client_date),
        COALESCE(shipment_mode, 'Unknown')
),

with_previous_year AS (
    SELECT
        *,

        LAG(on_time_rate) OVER (
            PARTITION BY shipment_mode
            ORDER BY delivery_year
        ) AS previous_year_on_time_rate

    FROM yearly_mode_metrics
)

SELECT
    delivery_year,
    shipment_mode,
    valid_delivery_shipments,
    late_shipments,

    ROUND(
        100 * on_time_rate,
        2
    ) AS on_time_rate_pct,

    ROUND(
        100 * (
            on_time_rate - previous_year_on_time_rate
        ),
        2
    ) AS year_over_year_change_pp,

    ROUND(
        average_days_late,
        2
    ) AS average_days_late,

    ROUND(
        100 * weighted_freight_ratio,
        2
    ) AS weighted_freight_ratio_pct

FROM with_previous_year;


-- View the overall yearly results
SELECT *
FROM analytics.yearly_overall_trends
ORDER BY delivery_year;


-- Verify the shipment-mode trend view
SELECT *
FROM analytics.yearly_mode_trends
WHERE shipment_mode <> 'Unknown'
ORDER BY shipment_mode, delivery_year;
