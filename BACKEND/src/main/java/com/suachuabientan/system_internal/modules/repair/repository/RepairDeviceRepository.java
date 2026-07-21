package com.suachuabientan.system_internal.modules.repair.repository;

import com.suachuabientan.system_internal.modules.repair.entity.RepairDevice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface RepairDeviceRepository extends JpaRepository<RepairDevice, UUID> {
    List<RepairDevice> findByOrderIdOrderByCreatedAtAsc(UUID orderId);
    void deleteByOrderId(UUID orderId);
}
