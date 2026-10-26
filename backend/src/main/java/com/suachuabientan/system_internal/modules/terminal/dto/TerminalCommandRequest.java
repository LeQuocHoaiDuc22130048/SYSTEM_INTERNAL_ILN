package com.suachuabientan.system_internal.modules.terminal.dto;

import jakarta.validation.constraints.NotBlank;

public record TerminalCommandRequest(
        @NotBlank(message = "Lệnh không được để trống")
        String command
) {}
