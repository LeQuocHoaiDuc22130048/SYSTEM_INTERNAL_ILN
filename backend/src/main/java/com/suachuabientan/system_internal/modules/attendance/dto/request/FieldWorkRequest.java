package com.suachuabientan.system_internal.modules.attendance.dto.request;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
public record FieldWorkRequest(@NotBlank @Size(max = 2000) String note) {}
