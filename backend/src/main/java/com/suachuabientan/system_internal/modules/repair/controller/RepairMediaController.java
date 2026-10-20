package com.suachuabientan.system_internal.modules.repair.controller;

import com.suachuabientan.system_internal.modules.repair.service.RepairMediaStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.InputStreamResource;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;


@RestController
@RequestMapping("/api/v1/repair-media")
@RequiredArgsConstructor
public class RepairMediaController {
    private final RepairMediaStorageService repairMediaStorageService;

    @GetMapping("/{storedName:.+}")
    public ResponseEntity<Resource> getMedia(@PathVariable String storedName) {
        RepairMediaStorageService.DownloadedMedia media = repairMediaStorageService.load(storedName);
        MediaType mediaType = resolveMediaType(storedName, media.contentType());
        return ResponseEntity.ok()
                .cacheControl(CacheControl.noStore())
                .contentLength(media.size())
                .contentType(mediaType)
                .body(new InputStreamResource(media.stream()));
    }

    private MediaType resolveMediaType(String filename, String rawContentType) {
        if (rawContentType != null && !rawContentType.isBlank()
                && !MediaType.APPLICATION_OCTET_STREAM_VALUE.equalsIgnoreCase(rawContentType)) {
            try {
                return MediaType.parseMediaType(rawContentType);
            } catch (Exception ignored) {
            }
        }
        String lower = filename.toLowerCase();
        if (lower.endsWith(".webp")) return MediaType.parseMediaType("image/webp");
        if (lower.endsWith(".png")) return MediaType.IMAGE_PNG;
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return MediaType.IMAGE_JPEG;
        if (lower.endsWith(".gif")) return MediaType.IMAGE_GIF;
        if (lower.endsWith(".svg")) return MediaType.parseMediaType("image/svg+xml");
        if (lower.endsWith(".mp4")) return MediaType.parseMediaType("video/mp4");
        if (lower.endsWith(".mov")) return MediaType.parseMediaType("video/quicktime");
        if (lower.endsWith(".pdf")) return MediaType.APPLICATION_PDF;
        return MediaType.APPLICATION_OCTET_STREAM;
    }
}
