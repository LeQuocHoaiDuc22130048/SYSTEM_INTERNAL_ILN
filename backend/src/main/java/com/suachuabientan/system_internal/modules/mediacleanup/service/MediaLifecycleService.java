package com.suachuabientan.system_internal.modules.mediacleanup.service;

import com.suachuabientan.system_internal.modules.mediacleanup.config.MediaCleanupProperties;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaAsset;
import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaReference;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaAssetStatus;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaModuleSource;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaReferenceType;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaAssetRepository;
import com.suachuabientan.system_internal.modules.mediacleanup.repository.MediaReferenceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class MediaLifecycleService {

    private final MediaAssetRepository mediaAssetRepository;
    private final MediaReferenceRepository mediaReferenceRepository;
    private final MediaCleanupProperties properties;

    /**
     * Đăng ký một tệp Media mới khi được tải lên S3/MinIO.
     * Mặc định gán expires_at = now + unreferencedUploadTtlHours (24h).
     * Khi tệp được gắn vào bản ghi nghiệp vụ (Message, RepairOrder...), expires_at sẽ được cập nhật theo chính sách lưu trữ.
     */
    @Transactional
    public MediaAsset registerUploadedMedia(
            String bucketName,
            String objectKey,
            String storageUrl,
            String originalFilename,
            String contentType,
            long fileSize,
            MediaModuleSource moduleSource,
            UUID createdBy,
            Instant customExpiresAt
    ) {
        Instant defaultExpiry = customExpiresAt != null
                ? customExpiresAt
                : Instant.now().plus(properties.getUnreferencedUploadTtlHours(), ChronoUnit.HOURS);

        Optional<MediaAsset> existing = mediaAssetRepository.findByBucketNameAndObjectKey(bucketName, objectKey);
        if (existing.isPresent()) {
            MediaAsset asset = existing.get();
            asset.setStorageUrl(storageUrl);
            asset.setOriginalFilename(originalFilename);
            asset.setContentType(contentType);
            asset.setFileSize(fileSize);
            asset.setModuleSource(moduleSource);
            asset.setStatus(MediaAssetStatus.ACTIVE);
            asset.setExpiresAt(defaultExpiry);
            return mediaAssetRepository.save(asset);
        }

        MediaAsset asset = MediaAsset.builder()
                .bucketName(bucketName)
                .objectKey(objectKey)
                .storageUrl(storageUrl)
                .originalFilename(originalFilename)
                .contentType(contentType)
                .fileSize(fileSize)
                .moduleSource(moduleSource != null ? moduleSource : MediaModuleSource.OTHER)
                .status(MediaAssetStatus.ACTIVE)
                .expiresAt(defaultExpiry)
                .maxRetries(properties.getMaxRetries())
                .createdBy(createdBy)
                .build();
        return mediaAssetRepository.save(asset);
    }

    /**
     * Gắn tham chiếu (Reference) vào Media theo đường dẫn storageUrl.
     */
    @Transactional
    public void attachReferenceByUrl(
            String storageUrl,
            MediaReferenceType referenceType,
            String referenceId
    ) {
        attachReferenceByUrl(storageUrl, referenceType, referenceId, null);
    }

    @Transactional
    public void attachReferenceByUrl(
            String storageUrl,
            MediaReferenceType referenceType,
            String referenceId,
            Instant newExpiresAt
    ) {
        if (!StringUtils.hasText(storageUrl) || !StringUtils.hasText(referenceId)) {
            return;
        }
        mediaAssetRepository.findByStorageUrl(storageUrl.trim()).ifPresent(asset -> {
            attachReferenceToAsset(asset, referenceType, referenceId.trim(), newExpiresAt);
        });
    }

    /**
     * Gắn tham chiếu (Reference) vào Media theo mediaId.
     */
    @Transactional
    public void attachReferenceById(
            UUID mediaId,
            MediaReferenceType referenceType,
            String referenceId,
            Instant newExpiresAt
    ) {
        if (mediaId == null || !StringUtils.hasText(referenceId)) {
            return;
        }
        mediaAssetRepository.findById(mediaId).ifPresent(asset -> {
            attachReferenceToAsset(asset, referenceType, referenceId.trim(), newExpiresAt);
        });
    }

    private void attachReferenceToAsset(
            MediaAsset asset,
            MediaReferenceType referenceType,
            String referenceId,
            Instant newExpiresAt
    ) {
        MediaReference ref = mediaReferenceRepository
                .findByMediaIdAndReferenceTypeAndReferenceId(asset.getId(), referenceType, referenceId)
                .orElseGet(() -> MediaReference.builder()
                        .mediaId(asset.getId())
                        .referenceType(referenceType)
                        .referenceId(referenceId)
                        .build());
        ref.setActive(true);
        ref.setReleasedAt(null);
        mediaReferenceRepository.save(ref);

        // Cập nhật hạn lưu trữ của MediaAsset khi đã có tham chiếu hợp lệ
        asset.setExpiresAt(newExpiresAt);
        if (asset.getStatus() == MediaAssetStatus.CLEANUP_IN_PROGRESS) {
            asset.setStatus(MediaAssetStatus.ACTIVE);
            asset.setClaimedByJobId(null);
            asset.setClaimedAt(null);
        }
        mediaAssetRepository.save(asset);
    }

    /**
     * Giải phóng tham chiếu khi đối tượng nghiệp vụ bị xóa/thu hồi/đóng.
     * Nếu Media không còn bất kỳ reference active nào khác, thiết lập expires_at để Cleanup Engine xử lý khi đến hạn.
     */
    @Transactional
    public void releaseReferenceByUrl(
            String storageUrl,
            MediaReferenceType referenceType,
            String referenceId
    ) {
        long ttlDays = referenceType == MediaReferenceType.MESSAGE
                ? properties.getDeletedMessageMediaTtlDays()
                : properties.getClosedRepairMediaTtlDays();
        Instant expiresAt = Instant.now().plus(Math.max(0, ttlDays), ChronoUnit.DAYS);
        releaseReferenceByUrl(storageUrl, referenceType, referenceId, expiresAt);
    }

    @Transactional
    public void releaseReferenceByUrl(
            String storageUrl,
            MediaReferenceType referenceType,
            String referenceId,
            Instant expiresAtWhenUnreferenced
    ) {
        if (!StringUtils.hasText(storageUrl) || !StringUtils.hasText(referenceId)) {
            return;
        }
        mediaAssetRepository.findByStorageUrl(storageUrl.trim()).ifPresent(asset -> {
            releaseReferenceForAsset(asset, referenceType, referenceId.trim(), expiresAtWhenUnreferenced);
        });
    }

    /**
     * Giải phóng tất cả tham chiếu của một thực thể (VD: xóa Message, đóng/xóa RepairOrder).
     */
    @Transactional
    public void releaseAllReferencesForEntity(
            MediaReferenceType referenceType,
            String referenceId,
            Instant expiresAtWhenUnreferenced
    ) {
        if (!StringUtils.hasText(referenceId)) {
            return;
        }
        List<MediaReference> activeRefs = mediaReferenceRepository
                .findByReferenceTypeAndReferenceIdAndActiveTrue(referenceType, referenceId.trim());
        Instant now = Instant.now();
        for (MediaReference ref : activeRefs) {
            ref.setActive(false);
            ref.setReleasedAt(now);
            mediaReferenceRepository.save(ref);

            mediaAssetRepository.findById(ref.getMediaId()).ifPresent(asset -> {
                boolean stillReferenced = mediaReferenceRepository.existsByMediaIdAndActiveTrue(asset.getId());
                if (!stillReferenced) {
                    asset.setExpiresAt(expiresAtWhenUnreferenced != null ? expiresAtWhenUnreferenced : now);
                    mediaAssetRepository.save(asset);
                }
            });
        }
    }

    private void releaseReferenceForAsset(
            MediaAsset asset,
            MediaReferenceType referenceType,
            String referenceId,
            Instant expiresAtWhenUnreferenced
    ) {
        Instant now = Instant.now();
        mediaReferenceRepository
                .findByMediaIdAndReferenceTypeAndReferenceId(asset.getId(), referenceType, referenceId)
                .ifPresent(ref -> {
                    ref.setActive(false);
                    ref.setReleasedAt(now);
                    mediaReferenceRepository.save(ref);
                });

        boolean stillReferenced = mediaReferenceRepository.existsByMediaIdAndActiveTrue(asset.getId());
        if (!stillReferenced) {
            asset.setExpiresAt(expiresAtWhenUnreferenced != null ? expiresAtWhenUnreferenced : now);
            mediaAssetRepository.save(asset);
        }
    }

    @Transactional(readOnly = true)
    public boolean isSoftDeleted(String bucketName, String objectKey) {
        return mediaAssetRepository.findByBucketNameAndObjectKey(bucketName, objectKey)
                .map(asset -> asset.getStatus() == MediaAssetStatus.SOFT_DELETED)
                .orElse(false);
    }
}

