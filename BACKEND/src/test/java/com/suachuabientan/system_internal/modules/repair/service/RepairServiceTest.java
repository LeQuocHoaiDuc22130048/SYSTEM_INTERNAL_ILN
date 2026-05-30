package com.suachuabientan.system_internal.modules.repair.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.util.OrderCodeGenerator;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import com.suachuabientan.system_internal.modules.repair.dto.request.AssignRequest;
import com.suachuabientan.system_internal.modules.repair.entity.RepairOrder;
import com.suachuabientan.system_internal.modules.repair.repository.RepairImageRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairOrderRepository;
import com.suachuabientan.system_internal.modules.repair.repository.RepairTimelineRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RepairServiceTest {
    @Mock private RepairOrderRepository repairOrderRepository;
    @Mock private RepairImageRepository repairImageRepository;
    @Mock private RepairTimelineRepository repairTimelineRepository;
    @Mock private UserRepository userRepository;
    @Mock private OrderCodeGenerator orderCodeGenerator;
    @Mock private NotificationService notificationService;
    @Mock private RepairMediaStorageService repairMediaStorageService;

    private RepairService repairService;

    @BeforeEach
    void setUp() {
        repairService = new RepairService(
                repairOrderRepository,
                repairImageRepository,
                repairTimelineRepository,
                userRepository,
                orderCodeGenerator,
                notificationService,
                repairMediaStorageService);
    }

    @Test
    void assignRejectsManagerAsTechnician() {
        UUID orderId = UUID.randomUUID();
        UUID managerId = UUID.randomUUID();
        UUID selectedUserId = UUID.randomUUID();
        UserEntity selectedUser = UserEntity.builder()
                .role(UserRole.MANAGER)
                .status(UserStatus.ACTIVE)
                .build();

        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(new RepairOrder()));
        when(userRepository.findByIdAndIsDeletedFalse(selectedUserId))
                .thenReturn(Optional.of(selectedUser));

        assertThrows(BusinessException.class,
                () -> repairService.assign(orderId, new AssignRequest(selectedUserId, null), managerId));

        verify(repairOrderRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void assignRejectsInactiveEmployee() {
        UUID orderId = UUID.randomUUID();
        UUID managerId = UUID.randomUUID();
        UUID selectedUserId = UUID.randomUUID();
        UserEntity selectedUser = UserEntity.builder()
                .role(UserRole.EMPLOYEE)
                .status(UserStatus.SUSPENDED)
                .build();

        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(new RepairOrder()));
        when(userRepository.findByIdAndIsDeletedFalse(selectedUserId))
                .thenReturn(Optional.of(selectedUser));

        assertThrows(BusinessException.class,
                () -> repairService.assign(orderId, new AssignRequest(selectedUserId, null), managerId));

        verify(repairOrderRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }
}
