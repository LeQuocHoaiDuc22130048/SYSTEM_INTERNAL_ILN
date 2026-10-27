package com.suachuabientan.system_internal.modules.device.service;

import com.suachuabientan.system_internal.modules.attendance.tablet.TabletDevice;
import com.suachuabientan.system_internal.modules.attendance.tablet.TabletDeviceRepository;
import com.suachuabientan.system_internal.modules.auth.entity.RefreshToken;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.modules.auth.repository.RefreshTokenRepository;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.device.dto.DeviceRequest;
import com.suachuabientan.system_internal.modules.device.dto.DeviceResponse;
import com.suachuabientan.system_internal.modules.device.entity.DeviceEntity;
import com.suachuabientan.system_internal.modules.device.enums.DeviceStatus;
import com.suachuabientan.system_internal.modules.device.repository.DeviceRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DeviceServiceTest {

    @Mock
    private DeviceRepository deviceRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private RefreshTokenRepository refreshTokenRepository;

    @Mock
    private TabletDeviceRepository tabletDeviceRepository;

    @Mock
    private NetworkPingService networkPingService;

    @InjectMocks
    private DeviceService deviceService;

    private UUID userId;
    private DeviceEntity sampleDevice;
    private UserEntity sampleUser;
    private TabletDevice sampleTablet;

    @BeforeEach
    void setUp() {
        userId = UUID.randomUUID();
        sampleDevice = DeviceEntity.builder()
                .deviceId("ATT-01")
                .name("Máy Chấm Công Cổng 1")
                .type("ATTENDANCE")
                .status(DeviceStatus.OFFLINE)
                .ipAddress("192.168.1.100")
                .pingMs(0)
                .version("1.0.0")
                .build();
        sampleDevice.setId(UUID.randomUUID());
        sampleDevice.setCreatedAt(Instant.now());
        sampleDevice.setUpdatedAt(Instant.now());

        sampleUser = UserEntity.builder()
                .username("maychamcong")
                .fullName("Máy Chấm Công")
                .employeeCode("NhanVien-2026-017")
                .role(UserRole.ATTENDANCE)
                .status(UserStatus.ACTIVE)
                .build();
        sampleUser.setId(UUID.randomUUID());
        sampleUser.setCreatedAt(Instant.now());
        sampleUser.setUpdatedAt(Instant.now());

        sampleTablet = new TabletDevice();
        sampleTablet.setId(UUID.randomUUID());
        sampleTablet.setAccountId(sampleUser.getId());
        sampleTablet.setName("Tablet chấm công");
        sampleTablet.setModel("Masscom Masstel Tab10 Edu");
        sampleTablet.setAppVersion("1.1.28");
        sampleTablet.setLastSeenAt(Instant.now());
    }

    @Test
    @DisplayName("Lấy danh sách thiết bị kết hợp cả tablet thật, users thật và custom devices")
    void getDevices_success() {
        when(tabletDeviceRepository.findAll()).thenReturn(List.of(sampleTablet));
        when(userRepository.findByRoleInAndStatusAndIsDeletedFalse(anyList(), any()))
                .thenReturn(List.of(sampleUser));
        when(refreshTokenRepository.findDistinctUserIds()).thenReturn(List.of());
        when(userRepository.findAllById(anyList())).thenReturn(List.of());
        when(refreshTokenRepository.findAllActiveTokens(any())).thenReturn(List.of());
        when(deviceRepository.findByIsDeletedFalseOrderByCreatedAtDesc())
                .thenReturn(List.of(sampleDevice));

        List<DeviceResponse> responses = deviceService.getDevices();
        assertEquals(2, responses.size());

        // Kiểm tra thiết bị tablet chấm công thật
        DeviceResponse tabletResp = responses.get(0);
        assertEquals("NhanVien-2026-017", tabletResp.deviceId());
        assertTrue(tabletResp.name().contains("Masscom Masstel Tab10 Edu"));
        assertEquals("ONLINE", tabletResp.status());
        assertEquals("1.1.28", tabletResp.version());

        // Kiểm tra thiết bị custom
        DeviceResponse customResp = responses.get(1);
        assertEquals("ATT-01", customResp.deviceId());
    }

    @Test
    @DisplayName("Ping thiết bị thành công cập nhật status ONLINE và pingMs thật")
    void pingDevice_online() {
        when(deviceRepository.findByIdAndIsDeletedFalse(sampleDevice.getId()))
                .thenReturn(Optional.of(sampleDevice));
        when(networkPingService.ping("192.168.1.100", null))
                .thenReturn(new NetworkPingService.PingResult(true, 14, "Ping thành công 14ms"));
        when(deviceRepository.save(any(DeviceEntity.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        DeviceResponse response = deviceService.pingDevice(sampleDevice.getId(), userId);

        assertEquals("ONLINE", response.status());
        assertEquals(14, response.pingMs());
        assertNotNull(response.lastActiveAt());
        verify(deviceRepository).save(sampleDevice);
    }

    @Test
    @DisplayName("Ping thiết bị không phản hồi cập nhật status OFFLINE và pingMs = 0")
    void pingDevice_offline() {
        when(deviceRepository.findByIdAndIsDeletedFalse(sampleDevice.getId()))
                .thenReturn(Optional.of(sampleDevice));
        when(networkPingService.ping("192.168.1.100", null))
                .thenReturn(new NetworkPingService.PingResult(false, 0, "Timeout"));
        when(deviceRepository.save(any(DeviceEntity.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        DeviceResponse response = deviceService.pingDevice(sampleDevice.getId(), userId);

        assertEquals("OFFLINE", response.status());
        assertEquals(0, response.pingMs());
        verify(deviceRepository).save(sampleDevice);
    }

    @Test
    @DisplayName("Thêm mới thiết bị thành công")
    void createDevice_success() {
        DeviceRequest request = new DeviceRequest("ATT-NEW", "Cổng Phụ", "ATTENDANCE", "192.168.1.150", "1.0.0");
        when(deviceRepository.existsByDeviceIdIgnoreCaseAndIsDeletedFalse("ATT-NEW")).thenReturn(false);
        when(userRepository.existsByUsernameAndIsDeletedFalse("att-new")).thenReturn(false);
        when(networkPingService.ping("192.168.1.150", null))
                .thenReturn(new NetworkPingService.PingResult(false, 0, "Chưa bật"));
        when(deviceRepository.save(any(DeviceEntity.class)))
                .thenAnswer(inv -> {
                    DeviceEntity d = inv.getArgument(0);
                    d.setId(UUID.randomUUID());
                    return d;
                });

        DeviceResponse response = deviceService.createDevice(request, userId);

        assertEquals("ATT-NEW", response.deviceId());
        assertEquals("Cổng Phụ", response.name());
        assertEquals("OFFLINE", response.status());
    }

    @Test
    @DisplayName("Toggle trạng thái thiết bị thành công")
    void toggleDeviceStatus_success() {
        when(deviceRepository.findByIdAndIsDeletedFalse(sampleDevice.getId()))
                .thenReturn(Optional.of(sampleDevice));
        when(deviceRepository.save(any(DeviceEntity.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        // Toggle từ OFFLINE -> ONLINE
        DeviceResponse response1 = deviceService.toggleDeviceStatus(sampleDevice.getId(), userId);
        assertEquals("ONLINE", response1.status());

        // Toggle lại từ ONLINE -> OFFLINE
        DeviceResponse response2 = deviceService.toggleDeviceStatus(sampleDevice.getId(), userId);
        assertEquals("OFFLINE", response2.status());
        assertEquals(0, response2.pingMs());
    }

    @Test
    @DisplayName("Nhận Heartbeat thành công")
    void receiveHeartbeat_success() {
        when(deviceRepository.findByDeviceIdAndIsDeletedFalse("ATT-01"))
                .thenReturn(Optional.of(sampleDevice));
        when(userRepository.findByUsernameAndIsDeletedFalse("att-01"))
                .thenReturn(Optional.empty());

        deviceService.receiveHeartbeat("att-01");

        assertEquals(DeviceStatus.ONLINE, sampleDevice.getStatus());
        assertNotNull(sampleDevice.getLastActiveAt());
        verify(deviceRepository).save(sampleDevice);
    }
}
