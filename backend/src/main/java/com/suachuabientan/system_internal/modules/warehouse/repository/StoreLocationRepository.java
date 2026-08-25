package com.suachuabientan.system_internal.modules.warehouse.repository;

import com.suachuabientan.system_internal.modules.warehouse.entity.StoreLocation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface StoreLocationRepository extends JpaRepository<StoreLocation, UUID> {
    Optional<StoreLocation> findByCodeAndIsDeletedFalse(String code);

    Optional<StoreLocation> findByCodeIgnoreCaseAndIsDeletedFalse(String code);

    Optional<StoreLocation> findByQrCodeAndIsDeletedFalse(String qrCode);

    Optional<StoreLocation> findByIdAndIsDeletedFalse(UUID id);

    @Query("SELECT sl FROM StoreLocation sl WHERE sl.isDeleted = false AND (" +
           "LOWER(TRIM(sl.code)) = LOWER(TRIM(:codeOrQr)) OR " +
           "LOWER(TRIM(COALESCE(sl.qrCode, ''))) = LOWER(TRIM(:codeOrQr)) OR " +
           "LOWER(TRIM(sl.name)) = LOWER(TRIM(:codeOrQr)) OR " +
           "LOWER(TRIM(sl.code)) = LOWER(TRIM(REPLACE(REPLACE(:codeOrQr, '_QR', ''), '_qr', ''))) OR " +
           "LOWER(TRIM(COALESCE(sl.qrCode, ''))) = LOWER(TRIM(REPLACE(REPLACE(:codeOrQr, '_QR', ''), '_qr', '')))" +
           ")")
    List<StoreLocation> findAllByCodeOrQrCodeIgnoreCase(@Param("codeOrQr") String codeOrQr);

    @Query("SELECT sl FROM StoreLocation sl WHERE sl.isDeleted = false AND (" +
           "LOWER(TRIM(sl.code)) = LOWER(TRIM(:codeOrQr)) OR " +
           "LOWER(TRIM(COALESCE(sl.qrCode, ''))) = LOWER(TRIM(:codeOrQr)) OR " +
           "LOWER(TRIM(sl.name)) = LOWER(TRIM(:codeOrQr)) OR " +
           "LOWER(TRIM(sl.code)) = LOWER(TRIM(REPLACE(REPLACE(:codeOrQr, '_QR', ''), '_qr', ''))) OR " +
           "LOWER(TRIM(COALESCE(sl.qrCode, ''))) = LOWER(TRIM(REPLACE(REPLACE(:codeOrQr, '_QR', ''), '_qr', '')))" +
           ")")
    Optional<StoreLocation> findByCodeOrQrCode(@Param("codeOrQr") String codeOrQr);
}
