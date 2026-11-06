package com.suachuabientan.system_internal.modules.customer.repository;

import com.suachuabientan.system_internal.modules.customer.entity.CustomerFeedback;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface CustomerFeedbackRepository extends JpaRepository<CustomerFeedback, UUID>, JpaSpecificationExecutor<CustomerFeedback> {

    Page<CustomerFeedback> findByCustomerIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID customerId, Pageable pageable);

    Optional<CustomerFeedback> findByIdAndIsDeletedFalse(UUID id);
}

