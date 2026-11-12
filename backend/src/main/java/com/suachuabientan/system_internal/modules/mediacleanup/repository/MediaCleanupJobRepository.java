package com.suachuabientan.system_internal.modules.mediacleanup.repository;

import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupJob;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.CleanupJobStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public interface MediaCleanupJobRepository extends JpaRepository<MediaCleanupJob, UUID> {

    List<MediaCleanupJob> findByStatusAndLastHeartbeatAtBefore(CleanupJobStatus status, Instant threshold);

    Page<MediaCleanupJob> findAllByOrderByStartedAtDesc(Pageable pageable);
}

