package com.suachuabientan.system_internal.modules.employee.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.modules.attendance.repository.AttendanceRecordRepository;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.auth.service.RbacService;
import com.suachuabientan.system_internal.modules.attendance.service.FaceRecognitionService;
import com.suachuabientan.system_internal.modules.repair.repository.RepairOrderRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EmployeeServiceTest {
    @Mock
    private UserRepository userRepository;
    @Mock
    private AttendanceRecordRepository attendanceRepository;
    @Mock
    private RepairOrderRepository repairOrderRepository;
    @Mock
    private FaceRecognitionService faceRecognitionService;
    @Mock
    private RbacService rbacService;

    private EmployeeService employeeService;
    private UUID employeeId;
    private UserEntity activeEmployee;

    @BeforeEach
    void setUp() {
        employeeService = new EmployeeService(
                userRepository,
                attendanceRepository,
                repairOrderRepository,
                faceRecognitionService,
                rbacService);
        employeeId = UUID.randomUUID();
        activeEmployee = new UserEntity();
        activeEmployee.setRole(UserRole.EMPLOYEE);
        activeEmployee.setStatus(UserStatus.ACTIVE);
        when(userRepository.findByIdAndIsDeletedFalse(employeeId))
                .thenReturn(Optional.of(activeEmployee));
    }

    @Test
    void enrollFaceStoresEncodingCreatedByAiService() {
        when(userRepository.save(any(UserEntity.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
        List<Double> dummyEncoding = List.of(0.2, -1.0, 3.5);
        when(faceRecognitionService.encode("image-data", "image/jpeg"))
                .thenReturn(dummyEncoding);
        when(faceRecognitionService.serializeEncoding(dummyEncoding))
                .thenReturn("[0.2,-1.0,3.5]");

        employeeService.enrollFace(employeeId, "image-data", "image/jpeg", UUID.randomUUID());

        assertEquals("[0.2,-1.0,3.5]", activeEmployee.getFaceEncoding());
        assertEquals(true, activeEmployee.getFaceEnrolled());
        verify(faceRecognitionService).encode("image-data", "image/jpeg");
        verify(userRepository).save(activeEmployee);
    }

    @Test
    void enrollFaceDoesNotSaveWhenAiRejectsImage() {
        when(faceRecognitionService.encode("bad-image", "image/jpeg"))
                .thenThrow(new BusinessException("Invalid image"));

        assertThrows(BusinessException.class,
                () -> employeeService.enrollFace(employeeId, "bad-image", "image/jpeg", UUID.randomUUID()));

        verify(userRepository, never()).save(any(UserEntity.class));
    }
}
