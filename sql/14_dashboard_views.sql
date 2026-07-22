\pset pager off

CREATE SCHEMA IF NOT EXISTS dashboard;

DROP VIEW IF EXISTS dashboard.executive_kpis;
DROP VIEW IF EXISTS dashboard.shipment_mode_scorecard;
DROP VIEW IF EXISTS dashboard.vendor_scorecard;
DROP VIEW IF EXISTS dashboard.vendor_mode_scorecard;
DROP VIEW IF EXISTS dashboard.country_scorecard;
DROP VIEW IF EXISTS dashboard.yearly_overall_trends;
DROP VIEW IF EXISTS dashboard.yearly_mode_trends;


-- =========================================================
-- 1. Executive KPI cards
-- =========================================================

CREATE VIEW dashboard.executive_kpis AS

SELECT
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

    ROUND(
        100.0 * AVG(is_on_time::integer)
        FILTER (
            WHERE scheduled_date_count = 1
              AND scheduled_delivery_date IS NOT NULL
              AND delivered_to_client_date IS NOT NULL
        ),
        2
    ) AS on_time_rate_pct,

    ROUND(
        AVG(delay_days)
        FILTER (
            WHERE scheduled_date_count = 1
              AND delivery_status = 'late'
        ),
        2
    ) AS average_days_late,

    ROUND(
        (
            PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY delay_days)
            FILTER (
                WHERE scheduled_date_count = 1
                  AND delivery_status = 'late'
            )
        )::numeric,
        2
    ) AS median_days_late,

    ROUND(
        100.0
        * SUM(freight_cost_usd)
          FILTER (
              WHERE freight_cost_usd IS NOT NULL
                AND total_line_item_value_usd > 0
          )
        / NULLIF(
            SUM(total_line_item_value_usd)
            FILTER (
                WHERE freight_cost_usd IS NOT NULL
                  AND total_line_item_value_usd > 0
            ),
            0
        ),
        2
    ) AS weighted_freight_ratio_pct,

    ROUND(
        (
            100.0 * PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY freight_cost_ratio)
            FILTER (
                WHERE freight_cost_ratio IS NOT NULL
            )
        )::numeric,
        2
    ) AS median_freight_ratio_pct

FROM analytics.shipment_summary;


-- =========================================================
-- 2. Shipment-mode scorecard
-- =========================================================

CREATE VIEW dashboard.shipment_mode_scorecard AS

WITH mode_metrics AS (
    SELECT
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

        AVG(is_on_time::integer)
        FILTER (
            WHERE scheduled_date_count = 1
              AND scheduled_delivery_date IS NOT NULL
              AND delivered_to_client_date IS NOT NULL
        ) AS on_time_rate,

        AVG(delay_days)
        FILTER (
            WHERE scheduled_date_count = 1
              AND delivery_status = 'late'
        ) AS average_days_late,

        COUNT(*) FILTER (
            WHERE freight_cost_usd IS NOT NULL
              AND total_line_item_value_usd > 0
        ) AS shipments_with_numeric_freight,

        SUM(freight_cost_usd)
        FILTER (
            WHERE freight_cost_usd IS NOT NULL
              AND total_line_item_value_usd > 0
        )
        /
        NULLIF(
            SUM(total_line_item_value_usd)
            FILTER (
                WHERE freight_cost_usd IS NOT NULL
                  AND total_line_item_value_usd > 0
            ),
            0
        ) AS weighted_freight_ratio

    FROM analytics.shipment_summary

    GROUP BY COALESCE(shipment_mode, 'Unknown')
)

SELECT
    shipment_mode,
    total_shipments,
    valid_delivery_shipments,
    late_shipments,

    ROUND(100 * on_time_rate, 2)
        AS on_time_rate_pct,

    ROUND(average_days_late, 2)
        AS average_days_late,

    shipments_with_numeric_freight,

    ROUND(100 * weighted_freight_ratio, 2)
        AS weighted_freight_ratio_pct

FROM mode_metrics;


-- =========================================================
-- 3. Copy finalized analytics views into dashboard schema
-- =========================================================

CREATE VIEW dashboard.vendor_scorecard AS
SELECT *
FROM analytics.vendor_scorecard;

CREATE VIEW dashboard.vendor_mode_scorecard AS
SELECT *
FROM analytics.vendor_mode_dashboard;

CREATE VIEW dashboard.country_scorecard AS
SELECT *
FROM analytics.country_scorecard;

CREATE VIEW dashboard.yearly_overall_trends AS
SELECT *
FROM analytics.yearly_overall_trends;

CREATE VIEW dashboard.yearly_mode_trends AS
SELECT *
FROM analytics.yearly_mode_trends;


-- Verify all dashboard views
SELECT
    table_name
FROM information_schema.views
WHERE table_schema = 'dashboard'
ORDER BY table_name;

SELECT *
FROM dashboard.executive_kpis;
