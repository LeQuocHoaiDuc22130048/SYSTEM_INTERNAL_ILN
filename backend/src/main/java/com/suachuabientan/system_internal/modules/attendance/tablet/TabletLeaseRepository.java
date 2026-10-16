package com.suachuabientan.system_internal.modules.attendance.tablet;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.UUID;
public interface TabletLeaseRepository extends JpaRepository<TabletLease, UUID> {
}
