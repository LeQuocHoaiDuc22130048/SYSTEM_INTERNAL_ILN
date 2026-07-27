package com.suachuabientan.system_internal.modules.warehouse.repository;

import com.suachuabientan.system_internal.modules.warehouse.entity.PartLot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PartLotRepository extends JpaRepository<PartLot, UUID> {
    List<PartLot> findByPartIdAndIsDeletedFalse(UUID partId);
    Optional<PartLot> findByPartIdAndStoreLocationIdAndIsDeletedFalse(UUID partId, UUID storeLocationId);
    Optional<PartLot> findByIdAndIsDeletedFalse(UUID id);
}
