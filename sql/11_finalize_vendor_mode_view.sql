\pset pager off

DROP VIEW IF EXISTS analytics.vendor_mode_dashboard;

CREATE VIEW analytics.vendor_mode_dashboard AS

SELECT
    vendor,
    vendor_type,
    shipment_mode,
    total_shipments,
    valid_delivery_shipments,
    late_shipments,
    on_time_rate_pct,
    average_days_late,
    shipments_with_numeric_freight,
    freight_data_coverage_pct,
    weighted_freight_ratio_pct,
    overall_risk_rank,
    mode_reliability_rank_within_vendor,
    mode_cost_rank_within_vendor,

    CASE
        WHEN shipment_mode = 'Unknown'
            THEN 'Missing shipment mode'

        WHEN vendor_type = 'Internal distribution source'
         AND on_time_rate_pct < 90
            THEN 'Review internal route'

        WHEN vendor_type = 'Internal distribution source'
            THEN 'Internal route benchmark'

        WHEN total_shipments >= 50
         AND on_time_rate_pct < 85
            THEN 'Urgent vendor-mode review'

        WHEN on_time_rate_pct < 90
            THEN 'Vendor-mode review'

        WHEN total_shipments >= 50
         AND on_time_rate_pct >= 95
            THEN 'Strong vendor-mode combination'

        ELSE 'Monitor'
    END AS review_category

FROM analytics.vendor_mode_scorecard;


SELECT
    vendor,
    shipment_mode,
    total_shipments,
    on_time_rate_pct,
    average_days_late,
    weighted_freight_ratio_pct,
    review_category
FROM analytics.vendor_mode_dashboard
WHERE review_category IN (
    'Urgent vendor-mode review',
    'Vendor-mode review',
    'Review internal route',
    'Missing shipment mode'
)
ORDER BY on_time_rate_pct, total_shipments DESC;
