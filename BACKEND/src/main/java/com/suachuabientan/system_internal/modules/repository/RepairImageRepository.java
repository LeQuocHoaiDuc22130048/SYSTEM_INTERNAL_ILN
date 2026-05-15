package com.suachuabientan.system_internal.modules.repository;

import com.suachuabientan.system_internal.modules.repair.entity.RepairImage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface RepairImageRepository extends JpaRepository<RepairImage, UUID> {

    List<RepairImage> findByOrderIdAndIsDeletedFalseOrderByUploadedAtAsc(UUID orderId);
}
