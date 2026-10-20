package com.suachuabientan.system_internal.modules.customer.repository;

import com.suachuabientan.system_internal.modules.customer.entity.CustomerAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CustomerAccountRepository extends JpaRepository<CustomerAccount, UUID> {
    List<CustomerAccount> findByCustomerIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID customerId);
    Optional<CustomerAccount> findByUserIdAndIsDeletedFalse(UUID userId);
    Optional<CustomerAccount> findByUserIdAndActiveTrueAndIsDeletedFalse(UUID userId);
    Optional<CustomerAccount> findByIdAndIsDeletedFalse(UUID id);
    boolean existsByCustomerIdAndActiveTrueAndIsDeletedFalse(UUID customerId);
}
