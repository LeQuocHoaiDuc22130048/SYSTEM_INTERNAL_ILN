package com.suachuabientan.system_internal.modules.employee.dto.response;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record EmployeeEmbeddingDeltaResponse(
        String modelName,
        Instant version,
        String checksum,
        Double matchThreshold,
        FaceEmbeddingCalibrationResponse calibration,
        List<EmployeeFaceEmbeddingResponse> changed,
        List<UUID> removedEmployeeIds
) {
}
