package com.suachuabientan.system_internal.modules.customer.repository;

import com.suachuabientan.system_internal.modules.customer.entity.RepairOrderConfirmation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface RepairOrderConfirmationRepository extends JpaRepository<RepairOrderConfirmation, UUID> {
    Optional<RepairOrderConfirmation> findByOrderIdAndIsDeletedFalse(UUID orderId);
}

