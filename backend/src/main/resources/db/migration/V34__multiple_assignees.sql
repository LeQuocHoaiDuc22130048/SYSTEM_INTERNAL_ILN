CREATE TABLE repair_order_assignees (
    order_id UUID NOT NULL,
    technician_id UUID NOT NULL,
    CONSTRAINT pk_repair_order_assignees PRIMARY KEY (order_id, technician_id)
);

ALTER TABLE repair_order_assignees
    ADD CONSTRAINT fk_repair_order_assignees_order FOREIGN KEY (order_id) REFERENCES repair_orders(id) ON DELETE CASCADE;

ALTER TABLE repair_order_assignees
    ADD CONSTRAINT fk_repair_order_assignees_technician FOREIGN KEY (technician_id) REFERENCES users(id) ON DELETE CASCADE;

-- Copy existing assignments
INSERT INTO repair_order_assignees (order_id, technician_id)
SELECT id, assigned_to FROM repair_orders WHERE assigned_to IS NOT NULL;
