-- Create devices table
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(150) NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'TECHNICIAN' | 'WAREHOUSE' | 'ATTENDANCE'
    status VARCHAR(20) NOT NULL DEFAULT 'OFFLINE', -- 'ONLINE' | 'OFFLINE'
    ip_address VARCHAR(45) NOT NULL,
    last_active_at TIMESTAMP,
    ping_ms INTEGER DEFAULT 0,
    version VARCHAR(20) DEFAULT '1.0.0',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP
);

-- Index for quick search and type filter
CREATE INDEX IF NOT EXISTS idx_devices_type ON devices (type) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_devices_device_id ON devices (device_id) WHERE is_deleted = FALSE;

-- Seed initial devices representing technician, warehouse, and attendance roles
INSERT INTO devices (device_id, name, type, status, ip_address, last_active_at, ping_ms, version) VALUES
('ATT-FREAD-01', 'Face Reader Cổng chính', 'ATTENDANCE', 'ONLINE', '192.168.10.50', NOW(), 18, '2.1.0'),
('ATT-FREAD-02', 'Face Reader Cổng sau', 'ATTENDANCE', 'ONLINE', '192.168.10.51', NOW(), 22, '2.1.0'),
('ATT-CAM-03', 'Camera AI Sảnh chính', 'ATTENDANCE', 'OFFLINE', '192.168.10.60', NULL, 0, '1.4.2'),
('WH-SCAN-01', 'Barcode Scanner Nhập Kho', 'WAREHOUSE', 'ONLINE', '192.168.20.10', NOW(), 12, '1.0.5'),
('WH-SCAN-02', 'Barcode Scanner Xuất Kho', 'WAREHOUSE', 'ONLINE', '192.168.20.11', NOW(), 15, '1.0.5'),
('WH-TAB-01', 'Tablet Quản Lý Kho Bãi', 'WAREHOUSE', 'OFFLINE', '192.168.20.20', NULL, 0, '3.2.1'),
('TECH-PAD-01', 'Máy tính bảng Kỹ thuật A', 'TECHNICIAN', 'ONLINE', '10.0.1.101', NOW(), 45, '4.0.0'),
('TECH-PAD-02', 'Máy tính bảng Kỹ thuật B', 'TECHNICIAN', 'OFFLINE', '10.0.1.102', NULL, 0, '4.0.0'),
('TECH-MOB-01', 'Mobile App Kỹ thuật viên 1', 'TECHNICIAN', 'ONLINE', '10.0.2.15', NOW(), 30, '4.1.2')
ON CONFLICT (device_id) DO NOTHING;
