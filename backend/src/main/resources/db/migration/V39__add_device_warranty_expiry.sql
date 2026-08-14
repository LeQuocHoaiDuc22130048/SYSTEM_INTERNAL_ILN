-- V39: Thêm ngày tháng năm bảo hành của thiết bị (warranty_expiry)
ALTER TABLE repair_devices ADD COLUMN warranty_expiry DATE;
