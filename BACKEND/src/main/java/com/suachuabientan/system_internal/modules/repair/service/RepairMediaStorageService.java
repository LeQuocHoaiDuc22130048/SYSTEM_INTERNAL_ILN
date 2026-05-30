package com.suachuabientan.system_internal.modules.repair.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.modules.repair.enums.RepairMediaType;
import io.minio.BucketExistsArgs;
import io.minio.GetObjectArgs;
import io.minio.GetObjectResponse;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.StatObjectArgs;
import io.minio.StatObjectResponse;
import io.minio.errors.ErrorResponseException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.util.Locale;
import java.util.Set;
import java.util.UUID;

@Service
public class RepairMediaStorageService {
    private static final long MAX_IMAGE_BYTES = 10L * 1024 * 1024;
    private static final Set<String> IMAGE_EXTENSIONS = Set.of("jpg", "jpeg", "png", "gif", "webp", "heic", "heif");
    private static final Set<String> VIDEO_EXTENSIONS = Set.of("mp4", "mov", "m4v", "webm", "avi", "mkv", "3gp");

    private final MinioClient minioClient;
    private final String bucket;
    private final long maxFileSize;

    public RepairMediaStorageService(
            MinioClient minioClient,
            @Value("${app.repair.minio.bucket:repair-media}") String bucket,
            @Value("${app.repair.max-file-size:52428800}") long maxFileSize) {
        this.minioClient = minioClient;
        this.bucket = bucket;
        this.maxFileSize = maxFileSize;
    }

    public StoredMedia store(MultipartFile file, RepairMediaType mediaType) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Tep tai len khong duoc de trong");
        }
        if (file.getSize() > maxFileSize
                || (mediaType == RepairMediaType.IMAGE && file.getSize() > MAX_IMAGE_BYTES)) {
            throw new BusinessException(mediaType == RepairMediaType.IMAGE
                    ? "Anh khong duoc vuot qua 10 MB"
                    : "Video khong duoc vuot qua 50 MB");
        }

        String originalName = StringUtils.cleanPath(
                StringUtils.hasText(file.getOriginalFilename()) ? file.getOriginalFilename() : "attachment");
        if (originalName.contains("..")) {
            throw new BusinessException("Ten tep khong hop le");
        }
        String extension = extensionOf(originalName);
        validateMediaType(mediaType, file.getContentType(), extension);

        String storedName = UUID.randomUUID() + (extension.isEmpty() ? "" : "." + extension);
        String contentType = StringUtils.hasText(file.getContentType())
                ? file.getContentType()
                : "application/octet-stream";
        try {
            ensureBucket();
            minioClient.putObject(PutObjectArgs.builder()
                    .bucket(bucket)
                    .object(storedName)
                    .contentType(contentType)
                    .stream(file.getInputStream(), file.getSize(), -1)
                    .build());
        } catch (Exception exception) {
            throw new BusinessException("Khong the luu tep dinh kem cua don");
        }
        return new StoredMedia("/api/v1/repair-media/" + storedName, originalName);
    }

    public DownloadedMedia load(String storedName) {
        if (!StringUtils.hasText(storedName) || storedName.contains("..")
                || storedName.contains("/") || storedName.contains("\\")) {
            throw new BusinessException("Duong dan tep khong hop le");
        }
        try {
            StatObjectResponse metadata = minioClient.statObject(StatObjectArgs.builder()
                    .bucket(bucket)
                    .object(storedName)
                    .build());
            GetObjectResponse stream = minioClient.getObject(GetObjectArgs.builder()
                    .bucket(bucket)
                    .object(storedName)
                    .build());
            return new DownloadedMedia(stream, metadata.contentType(), metadata.size());
        } catch (ErrorResponseException exception) {
            String code = exception.errorResponse().code();
            if ("NoSuchKey".equals(code) || "NoSuchObject".equals(code) || "NoSuchBucket".equals(code)) {
                throw new BusinessException("Khong tim thay tep dinh kem", 404);
            }
            throw new BusinessException("Khong the tai tep dinh kem", 502);
        } catch (Exception exception) {
            throw new BusinessException("Khong the tai tep dinh kem", 502);
        }
    }

    private void ensureBucket() throws Exception {
        if (!minioClient.bucketExists(BucketExistsArgs.builder().bucket(bucket).build())) {
            minioClient.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
        }
    }

    private void validateMediaType(RepairMediaType mediaType, String contentType, String extension) {
        String normalizedContentType = contentType == null ? "" : contentType.toLowerCase(Locale.ROOT);
        if (mediaType == RepairMediaType.IMAGE
                && !normalizedContentType.startsWith("image/")
                && !IMAGE_EXTENSIONS.contains(extension)) {
            throw new BusinessException("Tep duoc chon khong phai hinh anh");
        }
        if (mediaType == RepairMediaType.VIDEO
                && !normalizedContentType.startsWith("video/")
                && !VIDEO_EXTENSIONS.contains(extension)) {
            throw new BusinessException("Tep duoc chon khong phai video");
        }
    }

    private String extensionOf(String fileName) {
        int separator = fileName.lastIndexOf('.');
        if (separator < 0 || separator == fileName.length() - 1) {
            return "";
        }
        String extension = fileName.substring(separator + 1).toLowerCase(Locale.ROOT);
        return extension.matches("[a-z0-9]{1,10}") ? extension : "";
    }

    public record StoredMedia(String publicUrl, String originalFileName) {
    }

    public record DownloadedMedia(GetObjectResponse stream, String contentType, long size) {
    }
}
