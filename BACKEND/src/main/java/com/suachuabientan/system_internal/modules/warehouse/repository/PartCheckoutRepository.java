package com.suachuabientan.system_internal.modules.warehouse.repository;

import com.suachuabientan.system_internal.modules.warehouse.entity.PartCheckout;
import com.suachuabientan.system_internal.modules.warehouse.enums.CheckoutStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PartCheckoutRepository extends JpaRepository<PartCheckout, UUID> {
    Optional<PartCheckout> findByIdAndIsDeletedFalse(UUID id);

    Page<PartCheckout> findByPartIdAndIsDeletedFalseOrderByTakenAtDesc(UUID partId, Pageable pageable);

    Page<PartCheckout> findByStoreLocationIdAndIsDeletedFalseOrderByTakenAtDesc(UUID storeLocationId, Pageable pageable);

    Page<PartCheckout> findByIsDeletedFalseOrderByTakenAtDesc(Pageable pageable);

    List<PartCheckout> findByPartIdAndCheckoutStatusAndIsDeletedFalse(UUID partId, CheckoutStatus checkoutStatus);

    @Query("SELECT pc FROM PartCheckout pc WHERE pc.isDeleted = false " +
            "AND (:partId IS NULL OR pc.partId = :partId) " +
            "AND (:locationId IS NULL OR pc.storeLocationId = :locationId) " +
            "AND (:userId IS NULL OR pc.takenBy = :userId) " +
            "AND (:status IS NULL OR pc.checkoutStatus = :status) " +
            "ORDER BY pc.takenAt DESC")
    Page<PartCheckout> searchHistory(
            @Param("partId") UUID partId,
            @Param("locationId") UUID locationId,
            @Param("userId") UUID userId,
            @Param("status") CheckoutStatus status,
            Pageable pageable
    );
}
