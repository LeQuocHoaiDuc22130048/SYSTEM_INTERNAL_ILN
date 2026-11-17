package com.suachuabientan.system_internal.modules.quotation.repository;

import com.suachuabientan.system_internal.modules.quotation.entity.RepairQuotation;
import com.suachuabientan.system_internal.modules.quotation.enums.QuotationStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface RepairQuotationRepository extends JpaRepository<RepairQuotation, UUID> {

    Optional<RepairQuotation> findByIdAndIsDeletedFalse(UUID id);

    Optional<RepairQuotation> findByIdAndCustomerIdAndIsDeletedFalse(UUID id, UUID customerId);

    boolean existsByQuoteCode(String quoteCode);

    Page<RepairQuotation> findByCustomerIdAndIsDeletedFalseAndStatusNotOrderByCreatedAtDesc(
            UUID customerId, QuotationStatus excludedStatus, Pageable pageable);

    Page<RepairQuotation> findByCustomerIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID customerId, QuotationStatus status, Pageable pageable);

    @Query("""
            SELECT DISTINCT q FROM RepairQuotation q
            LEFT JOIN q.items i
            WHERE q.isDeleted = false
              AND (:customerId IS NULL OR q.customerId = :customerId)
              AND (:status IS NULL OR q.status = :status)
              AND (:repairOrderId IS NULL OR i.repairOrderId = :repairOrderId)
            ORDER BY q.createdAt DESC
            """)
    Page<RepairQuotation> searchQuotations(
            @Param("customerId") UUID customerId,
            @Param("status") QuotationStatus status,
            @Param("repairOrderId") UUID repairOrderId,
            Pageable pageable);

    List<RepairQuotation> findByCustomerIdAndStatusInAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID customerId, List<QuotationStatus> statuses);
}

