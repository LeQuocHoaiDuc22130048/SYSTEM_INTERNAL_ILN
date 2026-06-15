package com.suachuabientan.system_internal.modules.warehouse.repository;

import com.suachuabientan.system_internal.modules.warehouse.entity.Part;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface PartRepository extends JpaRepository<Part, UUID> {
    Optional<Part> findByIdAndIsDeletedFalse(UUID id);

    Optional<Part> findByIpnAndIsDeletedFalse(String ipn);
}
