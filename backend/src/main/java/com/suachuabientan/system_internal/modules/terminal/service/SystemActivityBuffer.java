package com.suachuabientan.system_internal.modules.terminal.service;

import com.suachuabientan.system_internal.modules.terminal.dto.SystemActivityDto;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.ConcurrentLinkedDeque;
import java.util.concurrent.CopyOnWriteArrayList;

@Slf4j
@Service
public class SystemActivityBuffer {

    private static final int MAX_BUFFER_SIZE = 500;
    private final ConcurrentLinkedDeque<SystemActivityDto> buffer = new ConcurrentLinkedDeque<>();
    private final CopyOnWriteArrayList<SseEmitter> emitters = new CopyOnWriteArrayList<>();

    public SystemActivityBuffer() {
        // Seed initial startup event
        record(SystemActivityDto.create(
                "SYSTEM",
                "STARTUP",
                "Hệ thống Terminal khởi tạo thành công",
                "system",
                "SYSTEM",
                "127.0.0.1",
                "SUCCESS",
                0L
        ));
    }

    public void record(SystemActivityDto activity) {
        if (activity == null) return;

        buffer.addFirst(activity);
        while (buffer.size() > MAX_BUFFER_SIZE) {
            buffer.pollLast();
        }

        // Broadcast to live SSE emitters
        List<SseEmitter> deadEmitters = new ArrayList<>();
        for (SseEmitter emitter : emitters) {
            try {
                emitter.send(SseEmitter.event()
                        .name("activity")
                        .id(activity.id())
                        .data(activity));
            } catch (IOException | IllegalStateException ex) {
                deadEmitters.add(emitter);
            }
        }
        if (!deadEmitters.isEmpty()) {
            emitters.removeAll(deadEmitters);
        }
    }

    public List<SystemActivityDto> getRecent(int limit, String category) {
        int targetLimit = (limit <= 0 || limit > MAX_BUFFER_SIZE) ? 100 : limit;
        String filterCat = (category != null && !category.isBlank() && !"ALL".equalsIgnoreCase(category))
                ? category.trim().toUpperCase()
                : null;

        List<SystemActivityDto> results = new ArrayList<>();
        for (SystemActivityDto item : buffer) {
            if (filterCat == null || filterCat.equalsIgnoreCase(item.category())) {
                results.add(item);
                if (results.size() >= targetLimit) {
                    break;
                }
            }
        }
        return results;
    }

    public SseEmitter createEmitter(String username) {
        SseEmitter emitter = new SseEmitter(30 * 60 * 1000L); // 30 minutes timeout

        emitters.add(emitter);

        emitter.onCompletion(() -> {
            emitters.remove(emitter);
            log.debug("SSE terminal session completed for user={}", username);
        });

        emitter.onTimeout(() -> {
            emitters.remove(emitter);
            emitter.complete();
            log.debug("SSE terminal session timed out for user={}", username);
        });

        emitter.onError(e -> {
            emitters.remove(emitter);
            log.debug("SSE terminal session error for user={}: {}", username, e.getMessage());
        });

        try {
            // Handshake greeting
            emitter.send(SseEmitter.event()
                    .name("init")
                    .data(Map.of(
                            "message", "Terminal stream connected",
                            "user", username != null ? username : "anonymous",
                            "activeSubscribers", emitters.size(),
                            "bufferSize", buffer.size()
                    )));

            // Replay recent 30 activities in chronological order
            List<SystemActivityDto> recent = getRecent(30, null);
            Collections.reverse(recent);
            for (SystemActivityDto item : recent) {
                emitter.send(SseEmitter.event().name("activity").id(item.id()).data(item));
            }
        } catch (IOException e) {
            emitters.remove(emitter);
        }

        return emitter;
    }

    public int getActiveSubscriberCount() {
        return emitters.size();
    }

    public int getBufferSize() {
        return buffer.size();
    }

    public void clear() {
        buffer.clear();
        record(SystemActivityDto.create(
                "SYSTEM",
                "CLEAR",
                "Nhật ký hoạt động trên bộ nhớ đệm đã được xóa sạch",
                "admin",
                "ADMIN",
                "127.0.0.1",
                "INFO",
                0L
        ));
    }
}
