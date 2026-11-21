package com.suachuabientan.system_internal.modules.quotation.repository;

import com.suachuabientan.system_internal.modules.quotation.entity.RepairQuotationItem;
import com.suachuabientan.system_internal.modules.quotation.enums.QuotationStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface RepairQuotationItemRepository extends JpaRepository<RepairQuotationItem, UUID> {

    @Query("""
            SELECT i.repairOrderId FROM RepairQuotationItem i
            JOIN i.quotation q
            WHERE i.isDeleted = false
              AND q.isDeleted = false
              AND q.status IN :activeStatuses
              AND i.repairOrderId IN :orderIds
            """)
    List<UUID> findOrderIdsWithActiveQuotations(
            @Param("orderIds") Collection<UUID> orderIds,
            @Param("activeStatuses") Collection<QuotationStatus> activeStatuses);

    @Query("""
            SELECT i FROM RepairQuotationItem i
            JOIN FETCH i.quotation q
            WHERE i.isDeleted = false
              AND q.isDeleted = false
              AND i.repairOrderId = :repairOrderId
            ORDER BY q.createdAt DESC
            """)
    List<RepairQuotationItem> findByRepairOrderIdWithQuotation(@Param("repairOrderId") UUID repairOrderId);
}

