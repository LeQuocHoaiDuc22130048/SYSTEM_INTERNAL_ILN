package com.suachuabientan.system_internal.modules.employee.dto.response;

import java.time.Instant;

public record FaceEmbeddingCalibrationResponse(
        Double threshold,
        Double far,
        Double frr,
        String datasetVersion,
        Instant calibratedAt,
        String reportPath
) {
}
