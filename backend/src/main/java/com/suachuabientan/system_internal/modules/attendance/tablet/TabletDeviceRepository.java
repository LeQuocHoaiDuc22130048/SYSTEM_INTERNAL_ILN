package com.suachuabientan.system_internal.modules.attendance.tablet;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import java.util.*;
public interface TabletDeviceRepository extends JpaRepository<TabletDevice, UUID> {
    Optional<TabletDevice> findByInstallationId(String installationId);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select d from TabletDevice d where d.id=:id")
    Optional<TabletDevice> lock(@Param("id") UUID id);
    List<TabletDevice> findByAccountId(UUID accountId);
}
