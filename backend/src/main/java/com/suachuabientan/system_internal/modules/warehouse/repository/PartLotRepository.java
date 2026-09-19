package com.suachuabientan.system_internal.modules.warehouse.repository;

import com.suachuabientan.system_internal.modules.warehouse.entity.PartLot;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PartLotRepository extends JpaRepository<PartLot, UUID> {
    List<PartLot> findByPartIdAndIsDeletedFalse(UUID partId);
    Optional<PartLot> findByPartIdAndStoreLocationIdAndIsDeletedFalse(UUID partId, UUID storeLocationId);
    Optional<PartLot> findByIdAndIsDeletedFalse(UUID id);
    List<PartLot> findByStoreLocationIdAndIsDeletedFalse(UUID storeLocationId);
    List<PartLot> findByStoreLocationIdInAndIsDeletedFalse(Collection<UUID> storeLocationIds);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT l FROM PartLot l WHERE l.id = :id AND l.isDeleted = false")
    Optional<PartLot> findByIdForUpdate(@Param("id") UUID id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT l FROM PartLot l WHERE l.partId = :partId AND l.storeLocationId = :storeLocationId AND l.isDeleted = false")
    Optional<PartLot> findByPartIdAndStoreLocationIdForUpdate(@Param("partId") UUID partId, @Param("storeLocationId") UUID storeLocationId);
}
