package com.suachuabientan.system_internal.modules.attendance.service;

import com.suachuabientan.system_internal.modules.attendance.tablet.TabletDevice;
import com.suachuabientan.system_internal.modules.attendance.tablet.TabletDeviceRepository;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AttendanceTabletMonitoringServiceTest {

    @Mock
    private TabletDeviceRepository tabletDeviceRepository;

    @Mock
    private NotificationService notificationService;

    @InjectMocks
    private AttendanceTabletMonitoringService monitoringService;

    private final UUID tabletId = UUID.randomUUID();
    private TabletDevice onlineTablet;
    private TabletDevice offlineTablet;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(monitoringService, "disconnectThresholdSeconds", 180L);

        onlineTablet = new TabletDevice();
        onlineTablet.setId(tabletId);
        onlineTablet.setName("Tablet chấm công");
        onlineTablet.setModel("Masscom Masstel Tab10 Edu");
        onlineTablet.setStatus("APPROVED");
        onlineTablet.setLastSeenAt(Instant.now());

        offlineTablet = new TabletDevice();
        offlineTablet.setId(tabletId);
        offlineTablet.setName("Tablet chấm công");
        offlineTablet.setModel("Masscom Masstel Tab10 Edu");
        offlineTablet.setStatus("APPROVED");
        offlineTablet.setLastSeenAt(Instant.now().minusSeconds(300)); // 5 mins ago
    }

    @Test
    @DisplayName("Tablet trực tuyến không gửi thông báo cảnh báo")
    void monitorAttendanceTablets_OnlineTablet_NoNotification() {
        when(tabletDeviceRepository.findAll()).thenReturn(List.of(onlineTablet));

        monitoringService.monitorAttendanceTablets();

        verifyNoInteractions(notificationService);
        assertFalse(monitoringService.isTabletDisconnected(tabletId));
    }

    @Test
    @DisplayName("Tablet mất kết nối vượt ngưỡng sẽ gửi cảnh báo đến ADMIN và SUPER_ADMIN")
    void monitorAttendanceTablets_OfflineTablet_SendsNotification() {
        when(tabletDeviceRepository.findAll()).thenReturn(List.of(offlineTablet));

        monitoringService.monitorAttendanceTablets();

        verify(notificationService, times(1)).sendToRoles(
                eq(List.of(UserRole.ADMIN, UserRole.SUPER_ADMIN)),
                eq(NotificationType.ATTENDANCE_DEVICE_DISCONNECTED),
                contains("Mất kết nối"),
                contains("Masscom Masstel Tab10 Edu"),
                eq("ATTENDANCE_TABLET"),
                eq(tabletId.toString()),
                eq(true)
        );
        assertTrue(monitoringService.isTabletDisconnected(tabletId));

        // Quét lần 2: không gửi trùng lặp cảnh báo
        monitoringService.monitorAttendanceTablets();
        verify(notificationService, times(1)).sendToRoles(any(), any(), any(), any(), any(), any(), anyBoolean());
    }

    @Test
    @DisplayName("Khi tablet kết nối lại sẽ gửi thông báo phục hồi kết nối")
    void monitorAttendanceTablets_ReconnectedTablet_SendsRecoveryNotification() {
        // Lần 1: offline -> gửi cảnh báo
        when(tabletDeviceRepository.findAll()).thenReturn(List.of(offlineTablet));
        monitoringService.monitorAttendanceTablets();
        assertTrue(monitoringService.isTabletDisconnected(tabletId));

        // Lần 2: tablet online lại
        when(tabletDeviceRepository.findAll()).thenReturn(List.of(onlineTablet));
        monitoringService.monitorAttendanceTablets();

        assertFalse(monitoringService.isTabletDisconnected(tabletId));
        verify(notificationService, times(1)).sendToRoles(
                eq(List.of(UserRole.ADMIN, UserRole.SUPER_ADMIN)),
                eq(NotificationType.ATTENDANCE_DEVICE_RECONNECTED),
                contains("kết nối lại"),
                contains("khôi phục kết nối thành công"),
                eq("ATTENDANCE_TABLET"),
                eq(tabletId.toString()),
                eq(true)
        );
    }

    @Test
    @DisplayName("Nhận heartbeat trực tiếp phục hồi kết nối ngay lập tức")
    void onHeartbeatReceived_RecoversDisconnectedTablet() {
        // Ban đầu đang trong trạng thái mất kết nối
        when(tabletDeviceRepository.findAll()).thenReturn(List.of(offlineTablet));
        monitoringService.monitorAttendanceTablets();
        assertTrue(monitoringService.isTabletDisconnected(tabletId));

        // Nhận heartbeat
        when(tabletDeviceRepository.findById(tabletId)).thenReturn(Optional.of(onlineTablet));
        monitoringService.onHeartbeatReceived(tabletId);

        assertFalse(monitoringService.isTabletDisconnected(tabletId));
        verify(notificationService, times(1)).sendToRoles(
                eq(List.of(UserRole.ADMIN, UserRole.SUPER_ADMIN)),
                eq(NotificationType.ATTENDANCE_DEVICE_RECONNECTED),
                contains("kết nối lại"),
                anyString(),
                eq("ATTENDANCE_TABLET"),
                eq(tabletId.toString()),
                eq(true)
        );
    }
}
