INSERT INTO control.dq_rules (table_name, check_type, threshold, query) VALUES
('stg_orders',      'row_count',    '0',    'SELECT COUNT(*) AS result FROM staging.stg_orders WHERE load_date = CURRENT_DATE()'),
('stg_orders',      'null_check',   '0',    'SELECT COUNT(*) AS result FROM staging.stg_orders WHERE order_id IS NULL'),
('stg_orders',      'freshness',    '24',   'SELECT DATEDIFF(hour, MAX(modified_date), CURRENT_TIMESTAMP()) AS result FROM staging.stg_orders'),
('stg_customers',   'row_count',    '0',    'SELECT COUNT(*) AS result FROM staging.stg_customers WHERE load_date = CURRENT_DATE()'),
('stg_customers',   'duplicate',    '0',    'SELECT COUNT(*) - COUNT(DISTINCT customer_id) AS result FROM staging.stg_customers WHERE load_date = CURRENT_DATE()'),
('stg_inventory',   'row_count',    '0',    'SELECT COUNT(*) AS result FROM staging.stg_inventory WHERE load_date = CURRENT_DATE()'),
('stg_inventory',   'range_check',  '0',    'SELECT COUNT(*) AS result FROM staging.stg_inventory WHERE quantity_on_hand < 0');
