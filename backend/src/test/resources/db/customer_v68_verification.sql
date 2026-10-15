-- Run after the migration chain in a disposable PostgreSQL database.
-- All fixtures are rolled back; this script raises an error on a failed assertion.
BEGIN;
DO $$
DECLARE
    customer_a UUID := gen_random_uuid();
    customer_b UUID := gen_random_uuid();
    staff_id UUID := gen_random_uuid();
    order_id UUID := gen_random_uuid();
    permission_count INTEGER;
BEGIN
    SELECT count(*) INTO permission_count
    FROM role_permissions rp JOIN roles r ON r.id = rp.role_id
    JOIN permissions p ON p.id = rp.permission_id
    WHERE p.code IN ('CUSTOMER_VIEW', 'CUSTOMER_MANAGE')
      AND r.code IN ('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE');
    IF permission_count <> 8 THEN RAISE EXCEPTION 'Missing customer permissions for managing roles'; END IF;
    IF EXISTS (SELECT 1 FROM role_permissions rp JOIN roles r ON r.id = rp.role_id
               JOIN permissions p ON p.id = rp.permission_id
               WHERE r.code IN ('TECHNICIAN', 'WAREHOUSE', 'ATTENDANCE') AND p.code = 'CUSTOMER_MANAGE')
    THEN RAISE EXCEPTION 'Customer management granted to an unexpected role'; END IF;

    INSERT INTO customers (id, customer_code, customer_name, type)
    VALUES (customer_a, 'KH-MIGRATION-A', 'Same customer name', 'COMPANY'),
           (customer_b, 'KH-MIGRATION-B', 'Same customer name', 'INDIVIDUAL');
    IF (SELECT count(*) FROM customers WHERE customer_name = 'Same customer name') <> 2
    THEN RAISE EXCEPTION 'Same-name customers were incorrectly merged'; END IF;

    BEGIN
        INSERT INTO customers (id, customer_code, customer_name, type)
        VALUES (gen_random_uuid(), 'KH-MIGRATION-A', 'Duplicate code', 'COMPANY');
        RAISE EXCEPTION 'Duplicate customer code was accepted';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    INSERT INTO users (id, username, password_hash, full_name, role, status)
    VALUES (staff_id, 'customer-migration-fixture', 'test-only', 'Test staff', 'EMPLOYEE', 'ACTIVE');
    INSERT INTO repair_orders (id, order_code, customer_name, device_name, received_by, received_at,
                               created_at, updated_at, is_deleted, status, priority)
    VALUES (order_id, 'RO-MIGRATION-FIXTURE', 'Legacy customer', 'Test device', staff_id, NOW(),
            NOW(), NOW(), FALSE, 'PENDING', 100);
    IF (SELECT customer_id FROM repair_orders WHERE id = order_id) IS NOT NULL
    THEN RAISE EXCEPTION 'Legacy order must remain unlinked'; END IF;
    UPDATE repair_orders SET customer_id = customer_a WHERE id = order_id;
    IF (SELECT customer_id FROM repair_orders WHERE id = order_id) <> customer_a
    THEN RAISE EXCEPTION 'Order link was not persisted'; END IF;
    BEGIN
        UPDATE repair_orders SET customer_id = gen_random_uuid() WHERE id = order_id;
        RAISE EXCEPTION 'Unknown customer link was accepted';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'repair_orders'
                   AND indexname = 'idx_repair_orders_customer_received')
    THEN RAISE EXCEPTION 'Missing customer order index'; END IF;
END $$;
ROLLBACK;
