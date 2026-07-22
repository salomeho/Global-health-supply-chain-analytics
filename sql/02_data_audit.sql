\pset pager off

-- 1. Overall dataset structure
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT id) AS unique_ids,
    COUNT(DISTINCT NULLIF(TRIM(po_so_number), '')) AS unique_po_so_numbers,
    COUNT(DISTINCT NULLIF(TRIM(asn_dn_number), '')) AS unique_asn_dn_numbers
FROM raw.shipments_raw;

-- 2. Missing values in important columns
SELECT
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(country), '') IS NULL
    ) AS missing_country,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(vendor), '') IS NULL
    ) AS missing_vendor,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(shipment_mode), '') IS NULL
    ) AS missing_shipment_mode,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(scheduled_delivery_date), '') IS NULL
    ) AS missing_scheduled_date,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(delivered_to_client_date), '') IS NULL
    ) AS missing_delivered_date,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(freight_cost_usd), '') IS NULL
    ) AS missing_freight_cost
FROM raw.shipments_raw;

-- 3. Shipment-mode distribution
SELECT
    COALESCE(NULLIF(TRIM(shipment_mode), ''), '[missing]') AS shipment_mode,
    COUNT(*) AS record_count
FROM raw.shipments_raw
GROUP BY 1
ORDER BY record_count DESC;

-- 4. Count weight and freight values that are not simple numbers
SELECT
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(weight_kilograms), '') IS NOT NULL
          AND REPLACE(TRIM(weight_kilograms), ',', '')
              !~ '^[0-9]+(\.[0-9]+)?$'
    ) AS nonnumeric_weight_values,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(freight_cost_usd), '') IS NOT NULL
          AND REPLACE(TRIM(freight_cost_usd), ',', '')
              !~ '^[0-9]+(\.[0-9]+)?$'
    ) AS nonnumeric_freight_values
FROM raw.shipments_raw;

-- 5. Examples of nonnumeric weight values
SELECT DISTINCT weight_kilograms
FROM raw.shipments_raw
WHERE NULLIF(TRIM(weight_kilograms), '') IS NOT NULL
  AND REPLACE(TRIM(weight_kilograms), ',', '')
      !~ '^[0-9]+(\.[0-9]+)?$'
LIMIT 10;

-- 6. Examples of nonnumeric freight values
SELECT DISTINCT freight_cost_usd
FROM raw.shipments_raw
WHERE NULLIF(TRIM(freight_cost_usd), '') IS NOT NULL
  AND REPLACE(TRIM(freight_cost_usd), ',', '')
      !~ '^[0-9]+(\.[0-9]+)?$'
LIMIT 10;

-- 7. Confirm that purchase orders contain multiple line items
SELECT
    COUNT(*) AS purchase_order_groups,
    COUNT(*) FILTER (WHERE line_item_count > 1)
        AS purchase_orders_with_multiple_rows,
    MAX(line_item_count) AS maximum_rows_in_one_purchase_order
FROM (
    SELECT
        po_so_number,
        COUNT(*) AS line_item_count
    FROM raw.shipments_raw
    WHERE NULLIF(TRIM(po_so_number), '') IS NOT NULL
    GROUP BY po_so_number
) AS po_counts;
