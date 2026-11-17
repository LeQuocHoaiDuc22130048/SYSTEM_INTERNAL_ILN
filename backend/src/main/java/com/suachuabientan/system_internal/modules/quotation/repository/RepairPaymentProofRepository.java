package com.suachuabientan.system_internal.modules.quotation.repository;

import com.suachuabientan.system_internal.modules.quotation.entity.RepairPaymentProof;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface RepairPaymentProofRepository extends JpaRepository<RepairPaymentProof, UUID> {

    List<RepairPaymentProof> findByQuotationIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID quotationId);

    Optional<RepairPaymentProof> findByIdAndIsDeletedFalse(UUID id);
}

