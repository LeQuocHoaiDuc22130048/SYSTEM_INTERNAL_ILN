package com.suachuabientan.system_internal.modules.mediacleanup.repository;

import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface MediaCleanupLogRepository extends JpaRepository<MediaCleanupLog, UUID> {

    Page<MediaCleanupLog> findByJobIdOrderByCreatedAtDesc(UUID jobId, Pageable pageable);

    List<MediaCleanupLog> findByMediaIdOrderByCreatedAtDesc(UUID mediaId);
}

