package com.suachuabientan.system_internal.modules.device.dto;

import java.time.Instant;
import java.util.UUID;

public record DeviceResponse(
    UUID id,
    String deviceId,
    String name,
    String type,
    String status,
    String ipAddress,
    Instant lastActiveAt,
    Integer pingMs,
    String version
) {}
