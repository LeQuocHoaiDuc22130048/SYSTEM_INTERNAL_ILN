package com.suachuabientan.system_internal.modules.attendance.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.modules.attendance.dto.request.FaceCheckinRequest;
import com.suachuabientan.system_internal.modules.attendance.entity.AttendanceRecord;
import com.suachuabientan.system_internal.modules.attendance.repository.AttendanceRecordRepository;
import com.suachuabientan.system_internal.modules.attendance.repository.WorkScheduleRepository;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AttendanceServiceTest {
    @Mock
    private AttendanceRecordRepository attendanceRecordRepository;
    @Mock
    private WorkScheduleRepository workScheduleRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private FaceRecognitionService faceRecognitionService;

    private AttendanceService attendanceService;
    private UUID employeeId;
    private UserEntity employee;

    @BeforeEach
    void setUp() {
        attendanceService = new AttendanceService(
                attendanceRecordRepository,
                workScheduleRepository,
                userRepository,
                faceRecognitionService);
        employeeId = UUID.randomUUID();
        employee = new UserEntity();
        employee.setId(employeeId);
        employee.setFullName("Test Employee");
        employee.setFaceEnrolled(true);
        employee.setFaceEncoding("[0.1,0.2,0.3,0.4,0.5,0.6]");
        when(userRepository.findByIdAndIsDeletedFalse(employeeId))
                .thenReturn(Optional.of(employee));
    }

    @Test
    void faceCheckRecordsAttendanceWhenEncodingMatches() {
        when(attendanceRecordRepository.findTodayRecords(any(), any(), any()))
                .thenReturn(List.of());
        when(attendanceRecordRepository.save(any(AttendanceRecord.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
        when(faceRecognitionService.verify("[0.1,0.2,0.3,0.4,0.5,0.6]", "image-data", "image/jpeg"))
                .thenReturn(new FaceRecognitionService.FaceVerificationResult(true, 0.98));

        var response = attendanceService.faceCheck(
                employeeId,
                new FaceCheckinRequest("image-data", "image/jpeg", "phone"));

        assertEquals(0.98, response.confidenceScore(), 0.0001);
        verify(attendanceRecordRepository).save(any(AttendanceRecord.class));
    }

    @Test
    void faceCheckRejectsEncodingThatDoesNotMatch() {
        when(faceRecognitionService.verify("[0.1,0.2,0.3,0.4,0.5,0.6]", "other-face", "image/jpeg"))
                .thenReturn(new FaceRecognitionService.FaceVerificationResult(false, 0.12));

        assertThrows(BusinessException.class, () -> attendanceService.faceCheck(
                employeeId,
                new FaceCheckinRequest("other-face", "image/jpeg", "phone")));

        verify(attendanceRecordRepository, never()).save(any(AttendanceRecord.class));
    }
}
