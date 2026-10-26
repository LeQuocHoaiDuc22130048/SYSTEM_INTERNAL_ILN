package com.suachuabientan.system_internal.modules.terminal.dto;

import java.time.Instant;

public record TerminalCommandResponse(
        String command,
        String output,
        String status,
        long executionTimeMs,
        Instant timestamp
) {
    public static TerminalCommandResponse success(String command, String output, long timeMs) {
        return new TerminalCommandResponse(command, output, "SUCCESS", timeMs, Instant.now());
    }

    public static TerminalCommandResponse error(String command, String errorMsg, long timeMs) {
        return new TerminalCommandResponse(command, errorMsg, "ERROR", timeMs, Instant.now());
    }
}
