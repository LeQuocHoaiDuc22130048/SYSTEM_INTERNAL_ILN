package com.suachuabientan.system_internal.modules.messaging.controller;

import com.suachuabientan.system_internal.modules.messaging.service.MessageMediaStorageService;
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

import java.time.Duration;

@RestController
@RequestMapping("/api/v1/message-media")
@RequiredArgsConstructor
public class MessageMediaController {
    private final MessageMediaStorageService messageMediaStorageService;

    @GetMapping("/{storedName:.+}")
    public ResponseEntity<Resource> getMedia(@PathVariable String storedName) {
        MessageMediaStorageService.DownloadedMedia media = messageMediaStorageService.load(storedName);
        return ResponseEntity.ok()
                .cacheControl(CacheControl.maxAge(Duration.ofDays(7)).cachePublic())
                .contentLength(media.size())
                .contentType(media.contentType() != null && !media.contentType().isBlank()
                        ? MediaType.parseMediaType(media.contentType())
                        : MediaType.APPLICATION_OCTET_STREAM)
                .body(new InputStreamResource(media.stream()));
    }
}
