\pset pager off

-- =========================================================
-- 1. Executive delivery KPIs
-- =========================================================

SELECT
    COUNT(*) AS total_line_item_records,

    COUNT(*) FILTER (
        WHERE is_on_time = TRUE
    ) AS early_or_on_time_records,

    COUNT(*) FILTER (
        WHERE delivery_status = 'late'
    ) AS late_records,

    ROUND(
        100.0
        * COUNT(*) FILTER (WHERE is_on_time = TRUE)
        / NULLIF(COUNT(*), 0),
        2
    ) AS on_time_rate_pct,

    ROUND(
        AVG(delay_days) FILTER (
            WHERE delivery_status = 'late'
        ),
        2
    ) AS average_days_late,

    ROUND(
        (
            PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY delay_days)
            FILTER (WHERE delivery_status = 'late')
        )::numeric,
        2
    ) AS median_days_late,

    COUNT(freight_cost_usd) AS records_with_numeric_freight_cost,

    ROUND(
        100 * AVG(freight_cost_ratio),
        2
    ) AS average_freight_cost_ratio_pct

FROM analytics.shipments;


-- =========================================================
-- 2. Shipment-mode performance using a CTE and window ranks
-- =========================================================

WITH mode_metrics AS (
    SELECT
        COALESCE(shipment_mode, 'Unknown') AS shipment_mode,

        COUNT(*) AS line_item_records,

        COUNT(*) FILTER (
            WHERE delivery_status = 'late'
        ) AS late_records,

        AVG(is_on_time::integer) AS on_time_rate,

        AVG(delay_days) FILTER (
            WHERE delivery_status = 'late'
        ) AS average_days_late,

        AVG(freight_cost_ratio) AS average_freight_ratio

    FROM analytics.shipments
    GROUP BY COALESCE(shipment_mode, 'Unknown')
),

ranked_modes AS (
    SELECT
        *,

        DENSE_RANK() OVER (
            ORDER BY on_time_rate DESC
        ) AS reliability_rank,

        DENSE_RANK() OVER (
            ORDER BY average_freight_ratio ASC NULLS LAST
        ) AS freight_cost_rank

    FROM mode_metrics
)

SELECT
    shipment_mode,
    line_item_records,
    late_records,

    ROUND(
        100 * on_time_rate,
        2
    ) AS on_time_rate_pct,

    ROUND(
        average_days_late,
        2
    ) AS average_days_late,

    ROUND(
        100 * average_freight_ratio,
        2
    ) AS average_freight_ratio_pct,

    reliability_rank,
    freight_cost_rank

FROM ranked_modes
ORDER BY reliability_rank, shipment_mode;
