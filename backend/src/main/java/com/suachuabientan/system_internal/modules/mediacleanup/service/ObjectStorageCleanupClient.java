package com.suachuabientan.system_internal.modules.mediacleanup.service;

import io.minio.MinioClient;
import io.minio.RemoveObjectArgs;
import io.minio.errors.ErrorResponseException;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class ObjectStorageCleanupClient {

    private final MinioClient minioClient;

    @Getter
    @Builder
    public static class StorageDeleteResult {
        private final boolean success;
        private final boolean alreadyAbsent;
        private final long durationMs;
        private final String errorCode;
        private final String errorMessage;
    }

    /**
     * Thực hiện xóa đối tượng trên S3 / S3-compatible Object Storage (MinIO).
     * Thao tác đảm bảo tính Idempotent: nếu object hoặc bucket đã không tồn tại (NoSuchKey / NoSuchObject / NoSuchBucket),
     * vẫn trả về success = true để PostgreSQL tiến hành cập nhật trạng thái SOFT_DELETED.
     */
    public StorageDeleteResult deleteObject(String bucketName, String objectKey) {
        long startNanos = System.nanoTime();
        try {
            minioClient.removeObject(
                    RemoveObjectArgs.builder()
                            .bucket(bucketName)
                            .object(objectKey)
                            .build()
            );
            long durationMs = (System.nanoTime() - startNanos) / 1_000_000L;
            return StorageDeleteResult.builder()
                    .success(true)
                    .alreadyAbsent(false)
                    .durationMs(durationMs)
                    .build();
        } catch (ErrorResponseException ex) {
            long durationMs = (System.nanoTime() - startNanos) / 1_000_000L;
            String code = ex.errorResponse() != null ? ex.errorResponse().code() : "S3_ERROR";
            if ("NoSuchKey".equalsIgnoreCase(code)
                    || "NoSuchObject".equalsIgnoreCase(code)
                    || "NoSuchBucket".equalsIgnoreCase(code)) {
                log.debug("Object already absent on S3 storage (bucket={}, key={}, code={})", bucketName, objectKey, code);
                return StorageDeleteResult.builder()
                        .success(true)
                        .alreadyAbsent(true)
                        .durationMs(durationMs)
                        .build();
            }
            log.warn("S3 error deleting object (bucket={}, key={}, code={}): {}", bucketName, objectKey, code, ex.getMessage());
            return StorageDeleteResult.builder()
                    .success(false)
                    .alreadyAbsent(false)
                    .durationMs(durationMs)
                    .errorCode(code)
                    .errorMessage(ex.getMessage())
                    .build();
        } catch (Exception ex) {
            long durationMs = (System.nanoTime() - startNanos) / 1_000_000L;
            String errorCode = ex.getClass().getSimpleName();
            log.warn("Failed to delete object from S3 storage (bucket={}, key={}): {}", bucketName, objectKey, ex.getMessage());
            return StorageDeleteResult.builder()
                    .success(false)
                    .alreadyAbsent(false)
                    .durationMs(durationMs)
                    .errorCode(errorCode)
                    .errorMessage(ex.getMessage())
                    .build();
        }
    }
}

