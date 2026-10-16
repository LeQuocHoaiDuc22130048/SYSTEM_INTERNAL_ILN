package com.suachuabientan.system_internal.modules.attendance.dto.request;

import com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record AttendanceSyncItemRequest(
        @NotBlank @Size(max = 120) String localLogId,
        @NotNull UUID employeeId,
        @NotNull AttendanceType type,
        @NotNull Instant checkTime,
        Instant mobileCheckTime,
        Double confidenceScore,
        @Size(max = 1024) List<Double> faceEmbedding,
        @Size(max = 3_000_000) String faceImageBase64,
        String imageContentType,
        @Size(max = 100, message = "Device ID tối đa 100 ký tự") String deviceId,
        String note,
        UUID leaseId,
        String leaseSignature
) {
    public AttendanceSyncItemRequest(String localLogId,UUID employeeId,AttendanceType type,Instant checkTime,
        Instant mobileCheckTime,Double confidenceScore,List<Double> faceEmbedding,String faceImageBase64,
        String imageContentType,String deviceId,String note){
        this(localLogId,employeeId,type,checkTime,mobileCheckTime,confidenceScore,faceEmbedding,faceImageBase64,imageContentType,deviceId,note,null,null);
    }
}
