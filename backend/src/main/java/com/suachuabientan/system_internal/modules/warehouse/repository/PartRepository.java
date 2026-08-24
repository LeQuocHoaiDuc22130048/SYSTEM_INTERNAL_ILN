package com.suachuabientan.system_internal.modules.warehouse.repository;

import com.suachuabientan.system_internal.modules.warehouse.entity.Part;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PartRepository extends JpaRepository<Part, UUID> {
    Optional<Part> findByIdAndIsDeletedFalse(UUID id);

    Optional<Part> findByIpnAndIsDeletedFalse(String ipn);

    List<Part> findByIsDeletedFalse();

    @Query("SELECT p FROM Part p WHERE p.isDeleted = false AND " +
           "(:keyword IS NULL OR :keyword = '' OR " +
           "LOWER(p.name) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
           "LOWER(p.ipn) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    Page<Part> searchParts(@Param("keyword") String keyword, Pageable pageable);
}

