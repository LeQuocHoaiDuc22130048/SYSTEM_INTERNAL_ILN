package com.suachuabientan.system_internal.modules.mediacleanup.repository;

import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaAsset;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaAssetStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MediaAssetRepository extends JpaRepository<MediaAsset, UUID> {

    /**
     * Quyết định thiết kế:
     * 1. Retention dựa trên expires_at <= :now
     * 2. Chỉ xóa Media hết hạn và không còn reference (NOT EXISTS active reference)
     * 3. Xóa theo batch 100 records (:batchSize)
     * 4. PostgreSQL Row Lock: FOR UPDATE OF m SKIP LOCKED
     */
    @Query(value = """
            SELECT m.*
            FROM media_assets m
            WHERE m.status = 'ACTIVE'
              AND m.expires_at IS NOT NULL
              AND m.expires_at <= :now
              AND (m.next_retry_at IS NULL OR m.next_retry_at <= :now)
              AND m.retry_count < m.max_retries
              AND NOT EXISTS (
                  SELECT 1
                  FROM media_references r
                  WHERE r.media_id = m.id
                    AND r.is_active = TRUE
              )
            ORDER BY m.expires_at ASC
            LIMIT :batchSize
            FOR UPDATE OF m SKIP LOCKED
            """, nativeQuery = true)
    List<MediaAsset> findCandidatesForCleanupWithRowLock(
            @Param("now") Instant now,
            @Param("batchSize") int batchSize
    );

    @Query("""
            SELECT COUNT(m)
            FROM MediaAsset m
            WHERE m.status = com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaAssetStatus.ACTIVE
              AND m.expiresAt IS NOT NULL
              AND m.expiresAt <= :now
              AND (m.nextRetryAt IS NULL OR m.nextRetryAt <= :now)
              AND m.retryCount < m.maxRetries
              AND NOT EXISTS (
                  SELECT 1
                  FROM MediaReference r
                  WHERE r.mediaId = m.id
                    AND r.active = true
              )
            """)
    long countEligibleCleanupCandidates(@Param("now") Instant now);

    List<MediaAsset> findByStatusAndClaimedAtBefore(MediaAssetStatus status, Instant threshold);

    Optional<MediaAsset> findByStorageUrl(String storageUrl);

    Optional<MediaAsset> findByBucketNameAndObjectKey(String bucketName, String objectKey);

    long countByStatus(MediaAssetStatus status);

    @Query("""
            SELECT COALESCE(SUM(m.fileSize), 0)
            FROM MediaAsset m
            WHERE m.status = com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaAssetStatus.SOFT_DELETED
            """)
    long sumTotalFreedBytes();

    Page<MediaAsset> findByStatusOrderByUpdatedAtDesc(MediaAssetStatus status, Pageable pageable);
}

