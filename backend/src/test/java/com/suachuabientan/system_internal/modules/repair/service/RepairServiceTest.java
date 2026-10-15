package com.suachuabientan.system_internal.modules.repair.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.util.OrderCodeGenerator;
import com.suachuabientan.system_internal.modules.customer.service.CustomerService;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerResponse;
import com.suachuabientan.system_internal.modules.customer.enums.CustomerType;
import com.suachuabientan.system_internal.modules.repair.dto.request.CreateRepairOrderRequest;
import com.suachuabientan.system_internal.modules.repair.dto.request.CreateRepairDeviceRequest;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import com.suachuabientan.system_internal.modules.repair.dto.request.AssignRequest;
import com.suachuabientan.system_internal.modules.repair.entity.RepairOrder;
import com.suachuabientan.system_internal.modules.repair.repository.RepairDeviceRepository;
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
    @Test void editingDevicesCannotAddAssignmentWithoutAssignmentPermission() {
        UUID id = UUID.randomUUID();
        RepairOrder order = new RepairOrder();
        order.setId(id);
        when(repairOrderRepository.findByIdAndIsDeletedFalse(id)).thenReturn(Optional.of(order));
        var first = new CreateRepairDeviceRequest("First", null, null, false, null, null, null);
        var second = new CreateRepairDeviceRequest("Second", null, null, false, null, null, UUID.randomUUID().toString());
        var request = new com.suachuabientan.system_internal.modules.repair.dto.request.UpdateRepairOrderRequest(
                "Customer", null, java.util.List.of(first, second), null);
        assertThrows(BusinessException.class, () -> repairService.update(id, request, manager()));
        verify(repairDeviceRepository, never()).deleteByOrderId(id);
    }
    @Test
    void delegatedDeletePermissionKeepsTheEmployeeOrderScope() {
        UserEntity employee = UserEntity.builder().role(UserRole.EMPLOYEE).status(UserStatus.ACTIVE).build();
        employee.setId(UUID.randomUUID());
        RepairOrder order = new RepairOrder();
        order.setId(UUID.randomUUID()); order.setReceivedBy(UUID.randomUUID());
        when(repairOrderRepository.findByIdAndIsDeletedFalse(order.getId())).thenReturn(Optional.of(order));
        var principal = new CustomUserDetails(employee, java.util.Set.of(), java.util.Set.of("REPAIR_DELETE"));
        BusinessException error = assertThrows(BusinessException.class, () -> repairService.delete(order.getId(), principal));
        org.junit.jupiter.api.Assertions.assertEquals(403, error.getStatusCode());
        verify(repairOrderRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void delegatedAssignmentCannotReorderAnotherEmployeesOrder() {
        UserEntity employee = UserEntity.builder().role(UserRole.EMPLOYEE).status(UserStatus.ACTIVE).build();
        employee.setId(UUID.randomUUID());
        RepairOrder order = new RepairOrder();
        order.setId(UUID.randomUUID()); order.setReceivedBy(UUID.randomUUID());
        when(repairOrderRepository.findByIdAndIsDeletedFalse(order.getId())).thenReturn(Optional.of(order));
        var request = new com.suachuabientan.system_internal.modules.repair.dto.request.ReorderRequest(java.util.List.of(
                new com.suachuabientan.system_internal.modules.repair.dto.request.ReorderRequest.PriorityItem(order.getId(), 1)));
        var principal = new CustomUserDetails(employee, java.util.Set.of(), java.util.Set.of("REPAIR_ASSIGN"));
        assertThrows(BusinessException.class, () -> repairService.reorder(request, principal));
        verify(repairOrderRepository, never()).updatePriority(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.anyInt());
    }
    @Mock private RepairOrderRepository repairOrderRepository;
    @Mock private RepairDeviceRepository repairDeviceRepository;
    @Mock private RepairImageRepository repairImageRepository;
    @Mock private RepairTimelineRepository repairTimelineRepository;
    @Mock private UserRepository userRepository;
    @Mock private OrderCodeGenerator orderCodeGenerator;
    @Mock private NotificationService notificationService;
    @Mock private RepairMediaStorageService repairMediaStorageService;
    @Mock private CustomerService customerService;

    private RepairService repairService;

    @BeforeEach
    void setUp() {
        repairService = new RepairService(
                repairOrderRepository,
                repairDeviceRepository,
                repairImageRepository,
                repairTimelineRepository,
                userRepository,
                orderCodeGenerator,
                notificationService,
                repairMediaStorageService,
                customerService);
    }

    @Test
    void createUsesSelectedCustomerRatherThanClientSuppliedName() {
        UUID customerId = UUID.randomUUID();
        when(customerService.requireActive(customerId)).thenReturn(new CustomerResponse(customerId,
                "KH-A", "Khách đúng", CustomerType.COMPANY, "0901234567", null, null, null,
                null, true, null, null));
        when(orderCodeGenerator.generate()).thenReturn("RO-TEST");
        when(repairOrderRepository.save(org.mockito.ArgumentMatchers.any())).thenAnswer(invocation -> {
            RepairOrder order = invocation.getArgument(0);
            order.setId(UUID.randomUUID());
            return order;
        });
        var device = new CreateRepairDeviceRequest("Biến tần", null, null, false, null, null, null);
        var response = repairService.create(new CreateRepairOrderRequest("Tên giả", "000",
                java.util.List.of(device), customerId), UUID.randomUUID());
        org.junit.jupiter.api.Assertions.assertEquals(customerId, response.customerId());
        org.junit.jupiter.api.Assertions.assertEquals("Khách đúng", response.customerName());
        org.junit.jupiter.api.Assertions.assertEquals("0901234567", response.customerPhone());
    }

    @Test
    void legacyCreateStillAcceptsUnlinkedCustomer() {
        when(orderCodeGenerator.generate()).thenReturn("RO-LEGACY");
        when(repairOrderRepository.save(org.mockito.ArgumentMatchers.any())).thenAnswer(invocation -> {
            RepairOrder order = invocation.getArgument(0);
            order.setId(UUID.randomUUID());
            return order;
        });
        var device = new CreateRepairDeviceRequest("Biến tần", null, null, false, null, null, null);
        var response = repairService.create(new CreateRepairOrderRequest("Khách cũ", "0901234567",
                java.util.List.of(device), null), UUID.randomUUID());
        org.junit.jupiter.api.Assertions.assertNull(response.customerId());
        org.junit.jupiter.api.Assertions.assertEquals("Khách cũ", response.customerName());
    }

    @Test
    void legacyCreateRejectsBlankNameWithoutCustomerId() {
        var device = new CreateRepairDeviceRequest("Biến tần", null, null, false, null, null, null);
        assertThrows(BusinessException.class, () -> repairService.create(
                new CreateRepairOrderRequest("  ", null, java.util.List.of(device), null), UUID.randomUUID()));
    }

    @Test
    void linkingOrderCopiesCustomerSnapshotAndRecordsHistory() {
        UUID customerId = UUID.randomUUID();
        RepairOrder order = new RepairOrder();
        order.setId(UUID.randomUUID());
        order.setStatus(RepairStatus.PENDING);
        order.setCustomerName("Tên cũ");
        when(repairOrderRepository.findByIdAndIsDeletedFalse(order.getId())).thenReturn(Optional.of(order));
        when(repairOrderRepository.save(order)).thenReturn(order);
        when(customerService.requireActive(customerId)).thenReturn(new CustomerResponse(customerId,
                "KH-A", "Khách đúng", CustomerType.INDIVIDUAL, "0901234567", null, null, null,
                null, true, null, null));
        var response = repairService.linkCustomer(order.getId(), customerId, "Xác minh hồ sơ", manager());
        org.junit.jupiter.api.Assertions.assertEquals(customerId, response.customerId());
        org.junit.jupiter.api.Assertions.assertEquals("Khách đúng", response.customerName());
        verify(repairTimelineRepository).save(org.mockito.ArgumentMatchers.argThat(timeline ->
                timeline.getNote().contains(customerId.toString()) && timeline.getNote().contains("Xác minh hồ sơ")
                        && timeline.getNote().contains("Tên cũ") && timeline.getNote().contains("Khách đúng")));
    }

    @Test
    void technicianCannotRelinkAnOrderEvenWhenAssigned() {
        UserEntity user = UserEntity.builder().role(UserRole.TECHNICIAN).status(UserStatus.ACTIVE).build();
        user.setId(UUID.randomUUID());
        assertThrows(BusinessException.class, () -> repairService.linkCustomer(
                UUID.randomUUID(), UUID.randomUUID(), "Lý do", new CustomUserDetails(user)));
    }

    @Test
    void transferringAnExistingOrderReplacesNameAndPhoneAndKeepsPreviousIdentityInHistory() {
        UUID previousCustomer = UUID.randomUUID();
        UUID nextCustomer = UUID.randomUUID();
        RepairOrder order = new RepairOrder();
        order.setId(UUID.randomUUID());
        order.setStatus(RepairStatus.DELIVERED);
        order.setCustomerId(previousCustomer);
        order.setCustomerName("Anh Nam");
        order.setCustomerPhone("0901111111");
        when(repairOrderRepository.findByIdAndIsDeletedFalse(order.getId())).thenReturn(Optional.of(order));
        when(repairOrderRepository.save(order)).thenReturn(order);
        when(customerService.requireActive(nextCustomer)).thenReturn(new CustomerResponse(nextCustomer,
                "KH-NEW", "Công ty Minh Phát", CustomerType.COMPANY, "0902222222", null, null, null,
                null, true, null, null));
        var response = repairService.linkCustomer(order.getId(), nextCustomer, "Chuyển đúng hồ sơ", manager());
        org.junit.jupiter.api.Assertions.assertEquals(nextCustomer, response.customerId());
        org.junit.jupiter.api.Assertions.assertEquals("Công ty Minh Phát", response.customerName());
        org.junit.jupiter.api.Assertions.assertEquals("0902222222", response.customerPhone());
        org.junit.jupiter.api.Assertions.assertEquals(RepairStatus.DELIVERED, order.getStatus());
        verify(repairTimelineRepository).save(org.mockito.ArgumentMatchers.argThat(timeline ->
                timeline.getNote().contains("Anh Nam") && timeline.getNote().contains(previousCustomer.toString())
                        && timeline.getNote().contains("Công ty Minh Phát") && timeline.getNote().contains("Chuyển đúng hồ sơ")));
    }

    @Test
    void nullCustomerLinkIsRejectedInsteadOfSilentlyRemovingOwnership() {
        assertThrows(BusinessException.class, () -> repairService.linkCustomer(
                UUID.randomUUID(), null, "Lý do", manager()));
    }

    private CustomUserDetails manager() {
        UserEntity user = UserEntity.builder().role(UserRole.MANAGER).status(UserStatus.ACTIVE).build();
        user.setId(UUID.randomUUID());
        return new CustomUserDetails(user, java.util.Set.of(), java.util.Set.of("CUSTOMER_ASSIGN", "CUSTOMER_TRANSFER"));
    }

    @Test
    void managerWithoutCustomerManagePermissionCannotRelinkOrders() {
        UserEntity user = UserEntity.builder().role(UserRole.MANAGER).status(UserStatus.ACTIVE).build();
        user.setId(UUID.randomUUID());
        BusinessException error = assertThrows(BusinessException.class, () -> repairService.linkCustomer(
                UUID.randomUUID(), UUID.randomUUID(), "Xác minh", new CustomUserDetails(user)));
        org.junit.jupiter.api.Assertions.assertEquals(403, error.getStatusCode());
    }

    @Test
    void employeeWithCustomerManageCannotRelinkAnotherEmployeesOrder() {
        UserEntity user = UserEntity.builder().role(UserRole.EMPLOYEE).status(UserStatus.ACTIVE).build();
        user.setId(UUID.randomUUID());
        RepairOrder order = new RepairOrder();
        order.setId(UUID.randomUUID());
        order.setReceivedBy(UUID.randomUUID());
        when(repairOrderRepository.findByIdAndIsDeletedFalse(order.getId())).thenReturn(Optional.of(order));
        BusinessException error = assertThrows(BusinessException.class, () -> repairService.linkCustomer(
                order.getId(), UUID.randomUUID(), "Xác minh", new CustomUserDetails(user,
                        java.util.Set.of(), java.util.Set.of("CUSTOMER_ASSIGN", "CUSTOMER_TRANSFER"))));
        org.junit.jupiter.api.Assertions.assertEquals(403, error.getStatusCode());
    }

    @Test
    void customerFilterKeepsEmployeeOrderVisibilityRestrictions() {
        UUID customerId = UUID.randomUUID();
        UserEntity employee = UserEntity.builder().role(UserRole.EMPLOYEE).status(UserStatus.ACTIVE).build();
        employee.setId(UUID.randomUUID());
        var pageable = org.springframework.data.domain.PageRequest.of(0, 20);
        when(repairOrderRepository.searchOrders(null, null, null, employee.getId().toString(),
                customerId.toString(), false, pageable)).thenReturn(org.springframework.data.domain.Page.empty(pageable));
        var result = repairService.getAll(null, null, null, customerId, pageable, new CustomUserDetails(employee));
        org.junit.jupiter.api.Assertions.assertTrue(result.isEmpty());
        verify(repairOrderRepository).searchOrders(null, null, null, employee.getId().toString(),
                customerId.toString(), false, pageable);
    }

    @Test
    void ordinaryUpdatePreservesLinkedCustomerSnapshot() {
        RepairOrder order = new RepairOrder();
        order.setId(UUID.randomUUID());
        order.setCustomerId(UUID.randomUUID());
        order.setCustomerName("Khách đúng");
        order.setCustomerPhone("0901234567");
        order.setStatus(RepairStatus.PENDING);
        when(repairOrderRepository.findByIdAndIsDeletedFalse(order.getId())).thenReturn(Optional.of(order));
        when(repairOrderRepository.save(order)).thenReturn(order);
        var response = repairService.update(order.getId(), new com.suachuabientan.system_internal.modules.repair.dto.request.UpdateRepairOrderRequest(
                "Tên sửa trên client cũ", "000", java.util.List.of(), null), manager());
        org.junit.jupiter.api.Assertions.assertEquals("Khách đúng", response.customerName());
        org.junit.jupiter.api.Assertions.assertEquals("0901234567", response.customerPhone());
        org.junit.jupiter.api.Assertions.assertEquals(order.getCustomerId(), response.customerId());
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
    void nonManagerCannotGetOrderNotAssignedToThem() {
        UUID orderId = UUID.randomUUID();
        UUID employeeId = UUID.randomUUID();
        
        RepairOrder order = new RepairOrder();
        order.setId(orderId);
        order.setOrderCode("RO-20260708-003");
        order.setDeviceName("Laptop Dell");
        order.setCustomerName("Khach Hang C");
        order.setCustomerPhone("0987654321");
        order.setStatus(RepairStatus.PENDING);
        order.setAssignedTo(UUID.randomUUID()); // Assigned to someone else
        order.setReceivedBy(UUID.randomUUID()); // Received by someone else
        
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

    @Test
    void toResponseFiltersOutSystemAndMediaActionsForNotes() {
        UUID orderId = UUID.randomUUID();
        UUID employeeId = UUID.randomUUID();

        RepairOrder order = new RepairOrder();
        order.setId(orderId);
        order.setOrderCode("RO-20260708-002");
        order.setDeviceName("Laptop Dell");
        order.setCustomerName("Khach Hang B");
        order.setCustomerPhone("0987654321");
        order.setStatus(RepairStatus.PENDING);
        order.setReceivedBy(employeeId);

        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));

        com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline t1 = 
                com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline.builder()
                        .action("Upload anh")
                        .note("8576.jpg")
                        .build();

        com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline t2 = 
                com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline.builder()
                        .action("Bắt đầu kiểm tra")
                        .note("Máy bị vỡ màn hình")
                        .build();

        com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline t3 = 
                com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline.builder()
                        .action("Tiếp nhận đơn")
                        .note("Đơn RO-20260708-002 được tạo bởi Admin")
                        .build();

        when(repairTimelineRepository.findByOrderIdOrderByCreatedAtDesc(orderId))
                .thenReturn(java.util.List.of(t1, t2, t3));

        UserEntity employee = UserEntity.builder()
                .role(UserRole.EMPLOYEE)
                .status(UserStatus.ACTIVE)
                .build();
        employee.setId(employeeId);

        CustomUserDetails userDetails = new CustomUserDetails(employee);

        var response = repairService.getById(orderId, userDetails);
        org.junit.jupiter.api.Assertions.assertNotNull(response);
        org.junit.jupiter.api.Assertions.assertEquals("Máy bị vỡ màn hình", response.notes());
    }

    @Test
    void toResponseReturnsEmptyNoteIfOnlySystemActionsExist() {
        UUID orderId = UUID.randomUUID();
        UUID employeeId = UUID.randomUUID();

        RepairOrder order = new RepairOrder();
        order.setId(orderId);
        order.setOrderCode("RO-20260708-002");
        order.setDeviceName("Laptop Dell");
        order.setCustomerName("Khach Hang B");
        order.setCustomerPhone("0987654321");
        order.setStatus(RepairStatus.PENDING);
        order.setReceivedBy(employeeId);

        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));

        com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline t1 = 
                com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline.builder()
                        .action("Upload anh")
                        .note("8576.jpg")
                        .build();

        com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline t2 = 
                com.suachuabientan.system_internal.modules.repair.entity.RepairTimeline.builder()
                        .action("Tiếp nhận đơn")
                        .note("Đơn RO-20260708-002 được tạo bởi Admin")
                        .build();

        when(repairTimelineRepository.findByOrderIdOrderByCreatedAtDesc(orderId))
                .thenReturn(java.util.List.of(t1, t2));

        UserEntity employee = UserEntity.builder()
                .role(UserRole.EMPLOYEE)
                .status(UserStatus.ACTIVE)
                .build();
        employee.setId(employeeId);

        CustomUserDetails userDetails = new CustomUserDetails(employee);

        var response = repairService.getById(orderId, userDetails);
        org.junit.jupiter.api.Assertions.assertNotNull(response);
        org.junit.jupiter.api.Assertions.assertEquals("", response.notes());
    }

    @Test
    void receiverNeedsIndependentCancelPermission() {
        UUID orderId = UUID.randomUUID();
        UUID receiverId = UUID.randomUUID();

        RepairOrder order = new RepairOrder();
        order.setId(orderId);
        order.setOrderCode("RO-20260729-001");
        order.setStatus(RepairStatus.PENDING);
        order.setReceivedBy(receiverId);

        when(repairOrderRepository.findByIdAndIsDeletedFalse(orderId))
                .thenReturn(Optional.of(order));
        when(repairDeviceRepository.findByOrderIdOrderByCreatedAtAsc(orderId))
                .thenReturn(java.util.Collections.emptyList());

        UserEntity receiverUser = UserEntity.builder()
                .role(UserRole.EMPLOYEE)
                .status(UserStatus.ACTIVE)
                .build();
        receiverUser.setId(receiverId);

        CustomUserDetails userDetails = new CustomUserDetails(receiverUser);

        // Test updating to CHECKING
        var requestChecking = new com.suachuabientan.system_internal.modules.repair.dto.request.UpdateStatusRequest(RepairStatus.CHECKING, "Chuyển sang kiểm tra");
        var responseChecking = repairService.updateStatus(orderId, requestChecking, userDetails);
        org.junit.jupiter.api.Assertions.assertEquals(RepairStatus.CHECKING.name(), responseChecking.status());

        // Test updating to CANCELLED
        var requestCancelled = new com.suachuabientan.system_internal.modules.repair.dto.request.UpdateStatusRequest(RepairStatus.CANCELLED, "Hủy đơn");
        org.junit.jupiter.api.Assertions.assertThrows(BusinessException.class,
                () -> repairService.updateStatus(orderId, requestCancelled, userDetails));
        CustomUserDetails cancelUser = new CustomUserDetails(receiverUser,
                java.util.Set.of(), java.util.Set.of("REPAIR_CANCEL"));
        var responseCancelled = repairService.updateStatus(orderId, requestCancelled, cancelUser);
        org.junit.jupiter.api.Assertions.assertEquals(RepairStatus.CANCELLED.name(), responseCancelled.status());
    }
}
