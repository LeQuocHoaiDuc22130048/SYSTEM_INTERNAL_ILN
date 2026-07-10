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

import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
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
                () -> repairService.assign(orderId, new AssignRequest(selectedUserId, java.util.List.of(selectedUserId), null), managerId));

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
                () -> repairService.assign(orderId, new AssignRequest(selectedUserId, java.util.List.of(selectedUserId), null), managerId));

        verify(repairOrderRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void employeeCannotGetOrderNotAssigned() {
        UUID orderId = UUID.randomUUID();
        UUID employeeId = UUID.randomUUID();
        
        RepairOrder order = new RepairOrder();
        order.setId(orderId);
        order.setAssignedTo(UUID.randomUUID());
        
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));
                
        UserEntity employee = UserEntity.builder()
                .role(UserRole.EMPLOYEE)
                .status(UserStatus.ACTIVE)
                .build();
        employee.setId(employeeId);
        
        CustomUserDetails userDetails = new CustomUserDetails(employee);
        
        assertThrows(BusinessException.class, () -> repairService.getById(orderId, userDetails));
    }

    @Test
    void employeeCanGetOrderAssignedToThem() {
        UUID orderId = UUID.randomUUID();
        UUID employeeId = UUID.randomUUID();
        
        RepairOrder order = new RepairOrder();
        order.setId(orderId);
        order.setOrderCode("RO-20260708-001");
        order.setDeviceName("Laptop Dell");
        order.setCustomerName("Khach Hang A");
        order.setCustomerPhone("0987654321");
        order.setStatus(RepairStatus.PENDING);
        order.setAssignedTo(employeeId);
        
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));
                
        UserEntity employee = UserEntity.builder()
                .role(UserRole.EMPLOYEE)
                .status(UserStatus.ACTIVE)
                .build();
        employee.setId(employeeId);
        
        CustomUserDetails userDetails = new CustomUserDetails(employee);
        
        var response = repairService.getById(orderId, userDetails);
        org.junit.jupiter.api.Assertions.assertNotNull(response);
        org.junit.jupiter.api.Assertions.assertEquals(orderId, response.id());
    }

    @Test
    void employeeCanGetOrderReceivedByThem() {
        UUID orderId = UUID.randomUUID();
        UUID employeeId = UUID.randomUUID();
        
        RepairOrder order = new RepairOrder();
        order.setId(orderId);
        order.setOrderCode("RO-20260708-002");
        order.setDeviceName("Laptop Dell");
        order.setCustomerName("Khach Hang B");
        order.setCustomerPhone("0987654321");
        order.setStatus(RepairStatus.PENDING);
        order.setReceivedBy(employeeId); // Received by them
        order.setAssignedTo(null); // Not assigned to them
        
        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));
                
        UserEntity employee = UserEntity.builder()
                .role(UserRole.EMPLOYEE)
                .status(UserStatus.ACTIVE)
                .build();
        employee.setId(employeeId);
        
        CustomUserDetails userDetails = new CustomUserDetails(employee);
        
        var response = repairService.getById(orderId, userDetails);
        org.junit.jupiter.api.Assertions.assertNotNull(response);
        org.junit.jupiter.api.Assertions.assertEquals(orderId, response.id());
    }
}
