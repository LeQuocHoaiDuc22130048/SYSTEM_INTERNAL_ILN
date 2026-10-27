-- Migration: V75__device_management_registry.sql
-- Create dedicated devices table for real physical & LAN device management and network monitoring

CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(150) NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'TECHNICIAN' | 'WAREHOUSE' | 'ATTENDANCE'
    status VARCHAR(20) NOT NULL DEFAULT 'OFFLINE', -- 'ONLINE' | 'OFFLINE'
    ip_address VARCHAR(45) NOT NULL,
    port INTEGER DEFAULT NULL,
    last_active_at TIMESTAMP WITH TIME ZONE,
    ping_ms INTEGER DEFAULT 0,
    version VARCHAR(20) DEFAULT '1.0.0',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_devices_type ON devices (type) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_devices_device_id ON devices (device_id) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices (status) WHERE is_deleted = FALSE;

