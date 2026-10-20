package com.suachuabientan.system_internal.modules.customer.repository;

import com.suachuabientan.system_internal.modules.customer.entity.PortalSupportConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface PortalSupportConfigRepository extends JpaRepository<PortalSupportConfig, UUID> {
}
