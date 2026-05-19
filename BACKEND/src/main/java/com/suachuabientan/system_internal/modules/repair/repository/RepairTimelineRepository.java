package com.suachuabientan.system_internal.modules.repair.repository;


import com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface RepairTimelineRepository extends JpaRepository<RepairTimeline, UUID> {
    /** Lịch sử theo thứ tự mới nhất trước */
    List<RepairTimeline> findByOrderIdOrderByCreatedAtDesc(UUID orderId);
}
