package com.suachuabientan.system_internal.modules.update.dto;

public record AppUpdateInfo(
    boolean updateAvailable,
    String latestVersion,
    String downloadUrl,
    boolean mandatory,
    String changelog,
    String sha256,
    Long fileSize,
    String minSupportedVersion,
    String channel
) {
    public AppUpdateInfo(
        boolean updateAvailable,
        String latestVersion,
        String downloadUrl,
        boolean mandatory,
        String changelog
    ) {
        this(updateAvailable, latestVersion, downloadUrl, mandatory, changelog, null, null, null, "PRODUCTION");
    }
}
