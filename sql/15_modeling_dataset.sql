\pset pager off

CREATE SCHEMA IF NOT EXISTS modeling;

DROP VIEW IF EXISTS modeling.late_shipment_features;

CREATE VIEW modeling.late_shipment_features AS

SELECT
    shipment_id,

    -- Target variable
    CASE
        WHEN delivery_status = 'late' THEN 1
        ELSE 0
    END AS late_flag,

    -- Chronological split
    CASE
        WHEN EXTRACT(YEAR FROM scheduled_delivery_date)
             BETWEEN 2006 AND 2013
            THEN 'train'

        WHEN EXTRACT(YEAR FROM scheduled_delivery_date) = 2014
            THEN 'validation'

        WHEN EXTRACT(YEAR FROM scheduled_delivery_date) = 2015
            THEN 'test'
    END AS data_split,

    -- Features known before delivery
    country,
    vendor,
    COALESCE(shipment_mode, 'Unknown') AS shipment_mode,

    EXTRACT(
        YEAR FROM scheduled_delivery_date
    )::integer AS scheduled_year,

    EXTRACT(
        MONTH FROM scheduled_delivery_date
    )::integer AS scheduled_month,

    line_item_count,

    total_line_item_value_usd,

    LN(
        1 + total_line_item_value_usd
    ) AS log_total_value_usd

FROM analytics.shipment_summary

WHERE scheduled_date_count = 1
  AND scheduled_delivery_date IS NOT NULL
  AND delivered_to_client_date IS NOT NULL
  AND EXTRACT(YEAR FROM scheduled_delivery_date)
      BETWEEN 2006 AND 2015;


-- Verify the chronological split and class balance
SELECT
    data_split,
    COUNT(*) AS total_shipments,
    SUM(late_flag) AS late_shipments,

    ROUND(
        100.0 * AVG(late_flag),
        2
    ) AS late_rate_pct

FROM modeling.late_shipment_features

GROUP BY data_split

ORDER BY
    CASE data_split
        WHEN 'train' THEN 1
        WHEN 'validation' THEN 2
        WHEN 'test' THEN 3
    END;
