-- V78: Cập nhật địa chỉ trung tâm kỹ thuật LikeNew sang 243 Quốc Lộ 1A, TP. Hồ Chí Minh
UPDATE portal_support_configs
SET workshop_address = '243 Quốc Lộ 1A, Khu phố 4, Phường Tam Bình, TP. Hồ Chí Minh, Việt Nam',
    updated_at = CURRENT_TIMESTAMP
WHERE id = '00000000-0000-0000-0000-000000000001'
  AND (workshop_address IS NULL OR workshop_address LIKE '%Văn Khê%' OR workshop_address = 'Trung tâm kỹ thuật sửa chữa thiết bị công nghiệp');

