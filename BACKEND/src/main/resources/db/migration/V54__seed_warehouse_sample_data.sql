-- V54__seed_warehouse_sample_data.sql
-- Thêm dữ liệu mẫu thử nghiệm cho Module Warehouse (ON CONFLICT (id) DO NOTHING)

-- 1. Danh mục linh kiện (categories)
INSERT INTO categories (id, name, description, not_selectable, created_at, updated_at, is_deleted)
VALUES
  ('20000000-0000-0000-0000-000000000001', 'MOSFET & IGBT Công suất', 'Linh kiện bán dẫn công suất đóng cắt', false, NOW(), NOW(), false),
  ('20000000-0000-0000-0000-000000000002', 'IC & Vi điều khiển', 'Vi điều khiển, Gate Driver, Optocoupler', false, NOW(), NOW(), false),
  ('20000000-0000-0000-0000-000000000003', 'Tụ điện', 'Tụ hóa, Tụ gốm, Tụ film công suất', false, NOW(), NOW(), false),
  ('20000000-0000-0000-0000-000000000004', 'Điện trở', 'Điện trở dán SMD, Điện trở công suất', false, NOW(), NOW(), false)
ON CONFLICT (id) DO NOTHING;

-- 2. Hãng sản xuất (manufacturers)
INSERT INTO manufacturers (id, name, description, created_at, updated_at, is_deleted)
VALUES
  ('10000000-0000-0000-0000-000000000001', 'Texas Instruments', 'Hãng sản xuất IC & Semiconductor Mỹ', NOW(), NOW(), false),
  ('10000000-0000-0000-0000-000000000002', 'STMicroelectronics', 'Hãng sản xuất MOSFET & Microcontroller Châu Âu', NOW(), NOW(), false),
  ('10000000-0000-0000-0000-000000000003', 'Infineon Technologies', 'Hãng sản xuất IGBT & Driver Đức', NOW(), NOW(), false)
ON CONFLICT (id) DO NOTHING;

-- 3. Vị trí kho vật lý (store_locations)
INSERT INTO store_locations (id, code, name, description, is_full, only_single_part, qr_code, created_at, updated_at, is_deleted)
VALUES
  ('30000000-0000-0000-0000-000000000001', 'LOC-A01-1', 'Khu A - Tủ 01 - Ngăn 1', 'Khu vực chứa linh kiện công suất IGBT & MOSFET', false, false, 'LOC_A01_1_QR', NOW(), NOW(), false),
  ('30000000-0000-0000-0000-000000000002', 'LOC-B02-2', 'Khu B - Tủ 02 - Ngăn 2', 'Khu vực chứa IC Driver & Tụ điện', false, false, 'LOC_B02_2_QR', NOW(), NOW(), false),
  ('30000000-0000-0000-0000-000000000003', 'LOC-C03-3', 'Khu C - Tủ 03 - Ngăn 3', 'Khu vực chứa Điện trở & Linh kiện nhỏ SMD', false, false, 'LOC_C03_3_QR', NOW(), NOW(), false)
ON CONFLICT (code) DO NOTHING;

-- 4. Thông tin linh kiện gốc (parts)
INSERT INTO parts (id, ipn, name, description, min_amount, max_amount, purchase_price, sale_price, manufacturing_status, category_id, manufacturer_id, parameters, created_at, updated_at, is_deleted)
VALUES
  ('40000000-0000-0000-0000-000000000001', 'FGH40N60SMD', 'IGBT 600V 40A TO-247', 'IGBT công suất cao dùng cho Inverter Sungrow / Huawei', 10, 200, 45000.00, 65000.00, 'ACTIVE', '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', '{"voltage": "600V", "current": "40A", "package": "TO-247"}', NOW(), NOW(), false),
  ('40000000-0000-0000-0000-000000000002', 'TK20A60W', 'MOSFET N-CH 600V 20A', 'MOSFET công suất nguồn Switching', 15, 300, 25000.00, 40000.00, 'ACTIVE', '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', '{"voltage": "600V", "current": "20A", "package": "TO-220"}', NOW(), NOW(), false),
  ('40000000-0000-0000-0000-000000000003', 'UCC27531', 'Single-Channel Gate Driver SOP-8', 'IC lái công suất High-Speed Gate Driver', 20, 500, 18000.00, 30000.00, 'ACTIVE', '20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '{"package": "SOP-8", "output_current": "2.5A"}', NOW(), NOW(), false),
  ('40000000-0000-0000-0000-000000000004', 'CAP-10UF-50V', 'Tụ Hóa 10uF 50V SMD', 'Tụ lọc nguồn SMD 105C', 50, 1000, 1500.00, 3000.00, 'ACTIVE', '20000000-0000-0000-0000-000000000003', NULL, '{"capacitance": "10uF", "voltage": "50V"}', NOW(), NOW(), false),
  ('40000000-0000-0000-0000-000000000005', 'RES-0805-10K', 'Điện trở SMD 0805 10K 1%', 'Điện trở dán chính xác 1%', 100, 5000, 200.00, 500.00, 'ACTIVE', '20000000-0000-0000-0000-000000000004', NULL, '{"resistance": "10K", "package": "0805"}', NOW(), NOW(), false)
ON CONFLICT (ipn) DO NOTHING;

-- 5. Lô linh kiện tồn kho theo vị trí (part_lots)
INSERT INTO part_lots (id, part_id, store_location_id, lot_code, amount, instock_unknown, needs_refill, origin, condition, received_date, created_at, updated_at, is_deleted)
VALUES
  ('50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'LOT-2026-IGBT-001', 95, false, false, 'NEW', 'TESTED_OK', '2026-08-01', NOW(), NOW(), false),
  ('50000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 'LOT-2026-MOS-002', 50, false, false, 'NEW', 'TESTED_OK', '2026-08-05', NOW(), NOW(), false),
  ('50000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000002', 'LOT-2026-IC-003', 200, false, false, 'NEW', 'TESTED_OK', '2026-08-10', NOW(), NOW(), false),
  ('50000000-0000-0000-0000-000000000004', '40000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000002', 'LOT-2026-CAP-004', 450, false, false, 'DISMANTLED', 'UNTESTED', '2026-08-12', NOW(), NOW(), false),
  ('50000000-0000-0000-0000-000000000005', '40000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000003', 'LOT-2026-RES-005', 1000, false, false, 'NEW', 'TESTED_OK', '2026-08-13', NOW(), NOW(), false)
ON CONFLICT (lot_code) DO NOTHING;

-- 6. Quản lý bo mạch kho (board_items)
INSERT INTO board_items (id, qr_code, name, category, description, status, location, serial_number, model, board_type, firmware, received_date, note, part_id, current_location_id, quantity, created_at, updated_at, is_deleted)
VALUES
  ('60000000-0000-0000-0000-000000000001', 'BOARD_SG110_CTRL_01', 'Bo Điều Khiển Inverter Sungrow SG110KTL', 'CONTROL_BOARD', 'Bo mạch điều khiển chính DSP', 'TESTED_OK', 'LOC-A01-1', 'SN-SG110-2026-01', 'SG110KTL', 'CONTROL', 'v2.1.4', '2026-08-01', 'Bo chạy ổn định', '40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 1, NOW(), NOW(), false),
  ('60000000-0000-0000-0000-000000000002', 'BOARD_SUN2000_PWR_02', 'Bo Công Suất Huawei SUN2000-100KTL', 'POWER_BOARD', 'Bo mạch động lực Driver & IGBT', 'UNTESTED', 'LOC-B02-2', 'SN-SUN2000-2026-02', 'SUN2000-100KTL', 'POWER', 'v1.0.0', '2026-08-10', 'Bo rã máy chưa kiểm tra', '40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', 1, NOW(), NOW(), false)
ON CONFLICT (qr_code) DO NOTHING;

-- 7. Lịch sử biến động kho Append-Only (stock_movements)
INSERT INTO stock_movements (id, movement_code, part_id, part_lot_id, storage_location_id, from_location_id, movement_type, quantity, amount, remaining_to_return, movement_status, purpose, note, created_at, updated_at, created_by, is_deleted)
SELECT
  '70000000-0000-0000-0000-000000000001',
  'PN-20260801-0001',
  '40000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  NULL,
  'IMPORT',
  100,
  100,
  0,
  'COMPLETED',
  'Nhập kho lô linh kiện mới từ nhà cung cấp',
  'Lô hàng kiểm định OK',
  NOW(),
  NOW(),
  u.id,
  false
FROM users u WHERE u.is_deleted = false LIMIT 1
ON CONFLICT (id) DO NOTHING;

INSERT INTO stock_movements (id, movement_code, part_id, part_lot_id, storage_location_id, from_location_id, movement_type, quantity, amount, remaining_to_return, movement_status, purpose, note, created_at, updated_at, created_by, is_deleted)
SELECT
  '70000000-0000-0000-0000-000000000002',
  'PX-20260813-0002',
  '40000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'USE_FOR_REPAIR',
  5,
  -5,
  5,
  'OPEN',
  'Lấy linh kiện IGBT sửa lỗi E05 Inverter Sungrow SG110KTL',
  'Mượn 5 con IGBT',
  NOW(),
  NOW(),
  u.id,
  false
FROM users u WHERE u.is_deleted = false LIMIT 1
ON CONFLICT (id) DO NOTHING;

-- 8. Nhật ký lấy/trả linh kiện (part_checkouts)
INSERT INTO part_checkouts (id, part_id, part_lot_id, store_location_id, taken_by, quantity, returned_quantity, taken_at, purpose, checkout_status, notes, created_at, updated_at, created_by, is_deleted)
SELECT
  '80000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  u.id,
  5,
  0,
  NOW(),
  'Lấy linh kiện IGBT sửa lỗi E05 Inverter Sungrow SG110KTL',
  'OPEN',
  'Kỹ thuật viên mượn 5 con',
  NOW(),
  NOW(),
  u.id,
  false
FROM users u WHERE u.is_deleted = false LIMIT 1
ON CONFLICT (id) DO NOTHING;
