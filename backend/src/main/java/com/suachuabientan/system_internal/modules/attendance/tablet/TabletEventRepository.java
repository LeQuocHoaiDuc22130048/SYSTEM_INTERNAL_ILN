package com.suachuabientan.system_internal.modules.attendance.tablet;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;
public interface TabletEventRepository extends JpaRepository<TabletEvent, UUID> {
    List<TabletEvent> findTop100ByDeviceIdOrderByOccurredAtDesc(UUID deviceId);
}
