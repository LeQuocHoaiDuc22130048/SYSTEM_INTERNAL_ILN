package com.suachuabientan.system_internal.modules.device.repository;

import com.suachuabientan.system_internal.modules.device.entity.DeviceEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DeviceRepository extends JpaRepository<DeviceEntity, UUID> {
    List<DeviceEntity> findByIsDeletedFalseOrderByCreatedAtDesc();
    Optional<DeviceEntity> findByIdAndIsDeletedFalse(UUID id);
    Optional<DeviceEntity> findByDeviceIdAndIsDeletedFalse(String deviceId);
    boolean existsByDeviceIdIgnoreCaseAndIsDeletedFalse(String deviceId);
    boolean existsByDeviceIdIgnoreCaseAndIdNotAndIsDeletedFalse(String deviceId, UUID id);
}
