\pset pager off

CREATE SCHEMA IF NOT EXISTS analytics;

DROP TABLE IF EXISTS analytics.shipments;

CREATE TABLE analytics.shipments AS

WITH typed AS (
    SELECT
        NULLIF(TRIM(id), '')::integer AS id,

        NULLIF(TRIM(project_code), '') AS project_code,
        NULLIF(TRIM(pq_number), '') AS pq_number,
        NULLIF(TRIM(po_so_number), '') AS po_so_number,
        NULLIF(TRIM(asn_dn_number), '') AS asn_dn_number,

        NULLIF(TRIM(country), '') AS country,
        NULLIF(TRIM(managed_by), '') AS managed_by,
        NULLIF(TRIM(fulfill_via), '') AS fulfill_via,
        NULLIF(TRIM(vendor_inco_term), '') AS vendor_inco_term,

        CASE
            WHEN TRIM(shipment_mode) IN ('', 'N/A')
                THEN NULL
            ELSE TRIM(shipment_mode)
        END AS shipment_mode,

        CASE
            WHEN TRIM(scheduled_delivery_date)
                ~ '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{2}$'
            THEN TO_DATE(
                TRIM(scheduled_delivery_date),
                'DD-Mon-YY'
            )
        END AS scheduled_delivery_date,

        CASE
            WHEN TRIM(delivered_to_client_date)
                ~ '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{2}$'
            THEN TO_DATE(
                TRIM(delivered_to_client_date),
                'DD-Mon-YY'
            )
        END AS delivered_to_client_date,

        CASE
            WHEN TRIM(delivery_recorded_date)
                ~ '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{2}$'
            THEN TO_DATE(
                TRIM(delivery_recorded_date),
                'DD-Mon-YY'
            )
        END AS delivery_recorded_date,

        NULLIF(TRIM(product_group), '') AS product_group,
        NULLIF(TRIM(sub_classification), '') AS sub_classification,
        NULLIF(TRIM(vendor), '') AS vendor,
        NULLIF(TRIM(item_description), '') AS item_description,
        NULLIF(TRIM(molecule_test_type), '') AS molecule_test_type,
        NULLIF(TRIM(brand), '') AS brand,
        NULLIF(TRIM(dosage), '') AS dosage,
        NULLIF(TRIM(dosage_form), '') AS dosage_form,

        NULLIF(
            TRIM(unit_of_measure_per_pack),
            ''
        )::integer AS unit_of_measure_per_pack,

        NULLIF(
            TRIM(line_item_quantity),
            ''
        )::integer AS line_item_quantity,

        NULLIF(
            TRIM(line_item_value),
            ''
        )::numeric AS line_item_value_usd,

        NULLIF(
            TRIM(pack_price),
            ''
        )::numeric AS pack_price_usd,

        NULLIF(
            TRIM(unit_price),
            ''
        )::numeric AS unit_price_usd,

        NULLIF(
            TRIM(manufacturing_site),
            ''
        ) AS manufacturing_site,

        NULLIF(
            TRIM(first_line_designation),
            ''
        ) AS first_line_designation,

        CASE
            WHEN REPLACE(
                TRIM(weight_kilograms),
                ',',
                ''
            ) ~ '^[0-9]+(\.[0-9]+)?$'
            THEN REPLACE(
                TRIM(weight_kilograms),
                ',',
                ''
            )::numeric
        END AS weight_kg,

        CASE
            WHEN REPLACE(
                TRIM(weight_kilograms),
                ',',
                ''
            ) ~ '^[0-9]+(\.[0-9]+)?$'
            THEN NULL
            ELSE NULLIF(TRIM(weight_kilograms), '')
        END AS weight_note,

        CASE
            WHEN REPLACE(
                TRIM(freight_cost_usd),
                ',',
                ''
            ) ~ '^[0-9]+(\.[0-9]+)?$'
            THEN REPLACE(
                TRIM(freight_cost_usd),
                ',',
                ''
            )::numeric
        END AS freight_cost_usd,

        CASE
            WHEN REPLACE(
                TRIM(freight_cost_usd),
                ',',
                ''
            ) ~ '^[0-9]+(\.[0-9]+)?$'
            THEN NULL
            ELSE NULLIF(TRIM(freight_cost_usd), '')
        END AS freight_cost_note,

        NULLIF(
            TRIM(line_item_insurance_usd),
            ''
        )::numeric AS line_item_insurance_usd

    FROM raw.shipments_raw
)

SELECT
    typed.*,

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
          AND line_item_value_usd > 0
        THEN ROUND(
            freight_cost_usd
            / line_item_value_usd,
            6
        )
    END AS freight_cost_ratio,

    EXTRACT(
        YEAR FROM delivered_to_client_date
    )::integer AS delivery_year

FROM typed;

CREATE UNIQUE INDEX idx_shipments_id
    ON analytics.shipments(id);

CREATE INDEX idx_shipments_vendor
    ON analytics.shipments(vendor);

CREATE INDEX idx_shipments_country
    ON analytics.shipments(country);

CREATE INDEX idx_shipments_mode
    ON analytics.shipments(shipment_mode);

CREATE INDEX idx_shipments_delivery_date
    ON analytics.shipments(delivered_to_client_date);

-- Verify the cleaned table
SELECT
    COUNT(*) AS cleaned_rows,
    COUNT(weight_kg) AS numeric_weight_rows,
    COUNT(freight_cost_usd) AS numeric_freight_rows,
    COUNT(*) FILTER (
        WHERE shipment_mode IS NULL
    ) AS missing_shipment_mode
FROM analytics.shipments;

SELECT
    delivery_status,
    COUNT(*) AS record_count
FROM analytics.shipments
GROUP BY delivery_status
ORDER BY delivery_status;
