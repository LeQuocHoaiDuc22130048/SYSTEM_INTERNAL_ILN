package com.suachuabientan.system_internal.modules.mediacleanup.enums;

public enum CleanupLogAction {
    S3_DELETE_AND_SOFT_DELETE,
    RETRY_SCHEDULED,
    MARK_PERMANENT_FAILED,
    SKIP_REFERENCED,
    RECOVERY_RESET
}

