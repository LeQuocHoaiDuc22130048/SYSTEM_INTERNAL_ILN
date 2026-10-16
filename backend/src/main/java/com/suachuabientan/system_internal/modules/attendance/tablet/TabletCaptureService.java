package com.suachuabientan.system_internal.modules.attendance.tablet;

import com.suachuabientan.system_internal.modules.attendance.dto.request.CheckinRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.FaceCheckinRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.response.AttendanceResponse;
import com.suachuabientan.system_internal.modules.attendance.service.AttendanceService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.UUID;

/** Holds device authorization and attendance capture within the same row-lock transaction. */
@Service
@RequiredArgsConstructor
public class TabletCaptureService {
    private final TabletDeviceService devices;
    private final AttendanceService attendance;

    @Transactional
    public AttendanceResponse check(UUID actor, String deviceId, String secret, CheckinRequest request) {
        devices.requireCapture(actor, deviceId, secret);
        return attendance.check(actor, request);
    }

    @Transactional
    public AttendanceResponse faceCheck(UUID actor, String deviceId, String secret, FaceCheckinRequest request) {
        devices.requireCapture(actor, deviceId, secret);
        return attendance.faceCheck(actor, request);
    }

    @Transactional
    public AttendanceResponse faceIdentify(UUID actor, String deviceId, String secret, FaceCheckinRequest request) {
        devices.requireCapture(actor, deviceId, secret);
        FaceCheckinRequest identified = deviceId == null ? request : new FaceCheckinRequest(
                request.faceImageBase64(), request.imageContentType(), deviceId);
        return attendance.faceIdentify(actor, identified);
    }
}
