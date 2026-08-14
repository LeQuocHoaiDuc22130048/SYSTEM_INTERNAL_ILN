package com.suachuabientan.system_internal.modules.update.dto;

public record AppUpdateInfo(
    boolean updateAvailable,
    String latestVersion,
    String downloadUrl,
    boolean mandatory,
    String changelog
) {}
