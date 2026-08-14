package com.suachuabientan.system_internal.modules.warehouse.repository;

import com.suachuabientan.system_internal.modules.warehouse.entity.StoreLocation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface StoreLocationRepository extends JpaRepository<StoreLocation, UUID> {
    Optional<StoreLocation> findByCodeAndIsDeletedFalse(String code);

    Optional<StoreLocation> findByQrCodeAndIsDeletedFalse(String qrCode);

    Optional<StoreLocation> findByIdAndIsDeletedFalse(UUID id);

    @Query("SELECT sl FROM StoreLocation sl WHERE sl.isDeleted = false AND (sl.code = :codeOrQr OR sl.qrCode = :codeOrQr)")
    Optional<StoreLocation> findByCodeOrQrCode(@Param("codeOrQr") String codeOrQr);
}
