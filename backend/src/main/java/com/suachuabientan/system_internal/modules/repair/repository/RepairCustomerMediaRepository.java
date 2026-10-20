package com.suachuabientan.system_internal.modules.repair.repository;

import com.suachuabientan.system_internal.modules.repair.entity.RepairCustomerMedia;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RepairCustomerMediaRepository extends JpaRepository<RepairCustomerMedia, UUID> {
    List<RepairCustomerMedia> findByOrderIdAndIsDeletedFalseOrderByPublishedAtDesc(UUID orderId);
    Optional<RepairCustomerMedia> findByOrderIdAndMediaIdAndIsDeletedFalse(UUID orderId, UUID mediaId);
    boolean existsByOrderIdAndMediaIdAndIsDeletedFalse(UUID orderId, UUID mediaId);
}
