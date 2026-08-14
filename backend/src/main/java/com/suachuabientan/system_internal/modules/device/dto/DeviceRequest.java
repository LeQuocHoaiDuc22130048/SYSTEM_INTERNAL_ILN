package com.suachuabientan.system_internal.modules.device.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record DeviceRequest(
    @NotBlank(message = "Mã thiết bị không được để trống")
    @Size(max = 100, message = "Mã thiết bị không vượt quá 100 ký tự")
    String deviceId,

    @NotBlank(message = "Tên thiết bị không được để trống")
    @Size(max = 150, message = "Tên thiết bị không vượt quá 150 ký tự")
    String name,

    @NotBlank(message = "Loại thiết bị không được để trống")
    @Pattern(regexp = "^(TECHNICIAN|WAREHOUSE|ATTENDANCE)$", message = "Loại thiết bị phải là: WAREHOUSE, TECHNICIAN hoặc ATTENDANCE")
    String type,

    @NotBlank(message = "IP Address không được để trống")
    @Size(max = 45, message = "IP Address không vượt quá 45 ký tự")
    String ipAddress,

    @Size(max = 20, message = "Phiên bản không vượt quá 20 ký tự")
    String version
) {}
