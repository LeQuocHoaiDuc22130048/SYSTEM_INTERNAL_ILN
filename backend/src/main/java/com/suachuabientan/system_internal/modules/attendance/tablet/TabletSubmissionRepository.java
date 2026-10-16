package com.suachuabientan.system_internal.modules.attendance.tablet;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.domain.*;
import java.util.*;
public interface TabletSubmissionRepository extends JpaRepository<TabletSubmission, UUID> {
    Optional<TabletSubmission> findByDeviceIdAndLocalLogId(UUID deviceId, String localLogId);
    Page<TabletSubmission> findByStatusIn(List<String> statuses, Pageable pageable);
    List<TabletSubmission> findByDeviceIdAndIdIn(UUID deviceId,List<UUID> ids);
    List<TabletSubmission> findByCreatedAtBeforeAndStatusIn(java.time.Instant cutoff,List<String> statuses,Pageable pageable);
}
