-- V38: Cho phép customer_phone và description trong bảng repair_orders được NULL theo yêu cầu
ALTER TABLE repair_orders ALTER COLUMN customer_phone DROP NOT NULL;
ALTER TABLE repair_orders ALTER COLUMN description DROP NOT NULL;
