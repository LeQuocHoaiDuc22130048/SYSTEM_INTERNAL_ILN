package com.suachuabientan.system_internal.modules.employee.dto.response;

import java.time.Instant;

public record EmployeeEmbeddingMetadataResponse(
        String modelName,
        Instant version,
        String checksum,
        Double matchThreshold,
        FaceEmbeddingCalibrationResponse calibration,
        long total
) {
}
