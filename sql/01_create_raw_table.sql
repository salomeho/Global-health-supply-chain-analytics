\pset pager off

CREATE SCHEMA IF NOT EXISTS raw;

DROP TABLE IF EXISTS raw.shipments_raw;

CREATE TABLE raw.shipments_raw (
    id TEXT,
    project_code TEXT,
    pq_number TEXT,
    po_so_number TEXT,
    asn_dn_number TEXT,
    country TEXT,
    managed_by TEXT,
    fulfill_via TEXT,
    vendor_inco_term TEXT,
    shipment_mode TEXT,
    pq_first_sent_to_client_date TEXT,
    po_sent_to_vendor_date TEXT,
    scheduled_delivery_date TEXT,
    delivered_to_client_date TEXT,
    delivery_recorded_date TEXT,
    product_group TEXT,
    sub_classification TEXT,
    vendor TEXT,
    item_description TEXT,
    molecule_test_type TEXT,
    brand TEXT,
    dosage TEXT,
    dosage_form TEXT,
    unit_of_measure_per_pack TEXT,
    line_item_quantity TEXT,
    line_item_value TEXT,
    pack_price TEXT,
    unit_price TEXT,
    manufacturing_site TEXT,
    first_line_designation TEXT,
    weight_kilograms TEXT,
    freight_cost_usd TEXT,
    line_item_insurance_usd TEXT
);

COPY raw.shipments_raw
FROM '/data/raw/SCMS_Delivery_History_Dataset.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    ENCODING 'UTF8'
);

SELECT COUNT(*) AS rows_loaded
FROM raw.shipments_raw;

SELECT
    id,
    country,
    vendor,
    shipment_mode,
    scheduled_delivery_date,
    delivered_to_client_date
FROM raw.shipments_raw
LIMIT 5;
