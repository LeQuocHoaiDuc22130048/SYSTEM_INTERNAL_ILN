ALTER TABLE repair_orders
    ADD COLUMN IF NOT EXISTS serial_number VARCHAR(100);
