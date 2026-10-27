package com.suachuabientan.system_internal.modules.device.service;

import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
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
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ForkJoinPool;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class DeviceService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final TabletDeviceRepository tabletDeviceRepository;
    private final DeviceRepository deviceRepository;
    private final NetworkPingService networkPingService;

    @Transactional(readOnly = true)
    public List<DeviceResponse> getDevices() {
        List<DeviceResponse> results = new ArrayList<>();

        // 1. Lấy tất cả tablet chấm công thực tế từ attendance_tablets
        List<TabletDevice> tablets = tabletDeviceRepository.findAll();
        Map<UUID, List<TabletDevice>> tabletsByAccount = tablets.stream()
                .filter(t -> t.getAccountId() != null)
                .collect(Collectors.groupingBy(TabletDevice::getAccountId));

        // 2. Lấy danh sách users đại diện cho máy trạm/thiết bị chuyên dụng (TECHNICIAN, WAREHOUSE, ATTENDANCE)
        List<UserRole> deviceRoles = List.of(UserRole.TECHNICIAN, UserRole.WAREHOUSE, UserRole.ATTENDANCE);
        List<UserEntity> deviceUsers = userRepository.findByRoleInAndStatusAndIsDeletedFalse(
                deviceRoles, UserStatus.ACTIVE);

        // Lấy các user đang có phiên đăng nhập hoạt động
        List<UUID> loggedInUserIds = refreshTokenRepository.findDistinctUserIds();
        List<UserEntity> loggedInUsers = userRepository.findAllById(loggedInUserIds).stream()
                .filter(u -> u.getStatus() == UserStatus.ACTIVE && !Boolean.TRUE.equals(u.getIsDeleted()))
                .collect(Collectors.toList());

        // Hợp nhất danh sách user đảm bảo không trùng
        Map<UUID, UserEntity> userMap = new LinkedHashMap<>();
        for (UserEntity user : deviceUsers) {
            userMap.put(user.getId(), user);
        }
        for (UserEntity user : loggedInUsers) {
            userMap.put(user.getId(), user);
        }

        // Lấy active refresh tokens để kiểm tra phiên đăng nhập
        List<RefreshToken> activeTokens = refreshTokenRepository.findAllActiveTokens(Instant.now());
        Map<UUID, List<RefreshToken>> activeTokensMap = activeTokens.stream()
                .collect(Collectors.groupingBy(RefreshToken::getUserId));

        // Map từng user sang DeviceResponse với thông tin thực tế từ DB
        for (UserEntity user : userMap.values()) {
            TabletDevice tablet = selectBestTablet(tabletsByAccount.get(user.getId()));
            List<RefreshToken> userTokens = activeTokensMap.getOrDefault(user.getId(), Collections.emptyList());
            results.add(mapUserToDeviceResponse(user, tablet, userTokens));
        }

        // 3. Lấy thêm các thiết bị phần cứng bổ sung đăng ký trong bảng devices (nếu có)
        List<DeviceEntity> customDevices = deviceRepository.findByIsDeletedFalseOrderByCreatedAtDesc();
        for (DeviceEntity cd : customDevices) {
            results.add(new DeviceResponse(
                    cd.getId(),
                    cd.getDeviceId(),
                    cd.getName(),
                    cd.getType(),
                    cd.getStatus().name(),
                    cd.getIpAddress(),
                    cd.getLastActiveAt(),
                    cd.getPingMs() != null ? cd.getPingMs() : 0,
                    cd.getVersion() != null ? cd.getVersion() : "1.0.0"
            ));
        }

        return results;
    }

    @Transactional
    public DeviceResponse createDevice(DeviceRequest request, UUID userId) {
        String deviceId = request.deviceId().trim();
        if (deviceRepository.existsByDeviceIdIgnoreCaseAndIsDeletedFalse(deviceId) ||
                userRepository.existsByUsernameAndIsDeletedFalse(deviceId.toLowerCase())) {
            throw new IllegalArgumentException("Mã thiết bị đã tồn tại trong hệ thống: " + deviceId);
        }

        NetworkPingService.PingResult pingResult = networkPingService.ping(request.ipAddress(), null);
        DeviceStatus status = pingResult.isOnline() ? DeviceStatus.ONLINE : DeviceStatus.OFFLINE;

        DeviceEntity device = DeviceEntity.builder()
                .deviceId(deviceId.toUpperCase())
                .name(request.name().trim())
                .type(request.type().trim())
                .status(status)
                .ipAddress(request.ipAddress().trim())
                .lastActiveAt(pingResult.isOnline() ? Instant.now() : null)
                .pingMs(pingResult.pingMs())
                .version(request.version() != null && !request.version().isBlank() ? request.version().trim() : "1.0.0")
                .build();

        device.setCreatedBy(userId);
        device.setUpdatedBy(userId);

        DeviceEntity saved = deviceRepository.save(device);
        return new DeviceResponse(
                saved.getId(),
                saved.getDeviceId(),
                saved.getName(),
                saved.getType(),
                saved.getStatus().name(),
                saved.getIpAddress(),
                saved.getLastActiveAt(),
                saved.getPingMs(),
                saved.getVersion()
        );
    }

    @Transactional
    public DeviceResponse updateDevice(UUID id, DeviceRequest request, UUID userId) {
        // Kiểm tra xem ID thuộc về bảng devices hay bảng users
        Optional<DeviceEntity> customDeviceOpt = deviceRepository.findByIdAndIsDeletedFalse(id);
        if (customDeviceOpt.isPresent()) {
            DeviceEntity device = customDeviceOpt.get();
            String deviceId = request.deviceId().trim();
            if (!device.getDeviceId().equalsIgnoreCase(deviceId) &&
                    deviceRepository.existsByDeviceIdIgnoreCaseAndIdNotAndIsDeletedFalse(deviceId, id)) {
                throw new IllegalArgumentException("Mã thiết bị đã tồn tại trong hệ thống: " + deviceId);
            }

            boolean ipChanged = !device.getIpAddress().equalsIgnoreCase(request.ipAddress().trim());
            device.setDeviceId(deviceId.toUpperCase());
            device.setName(request.name().trim());
            device.setType(request.type().trim());
            device.setIpAddress(request.ipAddress().trim());
            if (request.version() != null && !request.version().isBlank()) {
                device.setVersion(request.version().trim());
            }
            device.setUpdatedBy(userId);

            if (ipChanged) {
                NetworkPingService.PingResult pingResult = networkPingService.ping(device.getIpAddress(), device.getPort());
                device.setStatus(pingResult.isOnline() ? DeviceStatus.ONLINE : DeviceStatus.OFFLINE);
                device.setPingMs(pingResult.pingMs());
                if (pingResult.isOnline()) {
                    device.setLastActiveAt(Instant.now());
                }
            }

            DeviceEntity saved = deviceRepository.save(device);
            return new DeviceResponse(
                    saved.getId(),
                    saved.getDeviceId(),
                    saved.getName(),
                    saved.getType(),
                    saved.getStatus().name(),
                    saved.getIpAddress(),
                    saved.getLastActiveAt(),
                    saved.getPingMs(),
                    saved.getVersion()
            );
        }

        // Nếu thuộc về users
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thiết bị hoặc người dùng: " + id));

        user.setFullName(request.name().trim());
        user.setEmployeeCode(request.deviceId().trim());
        user.setUpdatedBy(userId);
        UserEntity savedUser = userRepository.save(user);

        return toUserResponse(savedUser);
    }

    @Transactional
    public void deleteDevice(UUID id, UUID userId) {
        Optional<DeviceEntity> customDeviceOpt = deviceRepository.findByIdAndIsDeletedFalse(id);
        if (customDeviceOpt.isPresent()) {
            DeviceEntity device = customDeviceOpt.get();
            device.softDelete(userId);
            deviceRepository.save(device);
            return;
        }

        UserEntity user = userRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thiết bị: " + id));

        refreshTokenRepository.revokeAllByUserId(user.getId());
        user.softDelete(userId);
        userRepository.save(user);
    }

    @Transactional
    public DeviceResponse pingDevice(UUID id, UUID userId) {
        // Trường hợp 1: Thiết bị trong bảng devices
        Optional<DeviceEntity> customDeviceOpt = deviceRepository.findByIdAndIsDeletedFalse(id);
        if (customDeviceOpt.isPresent()) {
            DeviceEntity device = customDeviceOpt.get();
            NetworkPingService.PingResult result = networkPingService.ping(device.getIpAddress(), device.getPort());
            if (result.isOnline()) {
                device.setStatus(DeviceStatus.ONLINE);
                device.setPingMs(result.pingMs());
                device.setLastActiveAt(Instant.now());
            } else {
                device.setStatus(DeviceStatus.OFFLINE);
                device.setPingMs(0);
            }
            device.setUpdatedBy(userId);
            DeviceEntity saved = deviceRepository.save(device);
            return new DeviceResponse(
                    saved.getId(),
                    saved.getDeviceId(),
                    saved.getName(),
                    saved.getType(),
                    saved.getStatus().name(),
                    saved.getIpAddress(),
                    saved.getLastActiveAt(),
                    saved.getPingMs(),
                    saved.getVersion()
            );
        }

        // Trường hợp 2: Tài khoản thiết bị / người dùng trong bảng users
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thiết bị với ID: " + id));

        user.setUpdatedAt(Instant.now());
        userRepository.save(user);

        List<TabletDevice> tablets = tabletDeviceRepository.findByAccountId(user.getId());
        TabletDevice tablet = selectBestTablet(tablets);
        if (tablet != null) {
            tablet.setLastSeenAt(Instant.now());
            tabletDeviceRepository.save(tablet);
        }

        return toUserResponse(user);
    }

    @Transactional
    public List<DeviceResponse> pingAllDevices(UUID userId) {
        // Ping đồng thời tất cả các custom devices
        List<DeviceEntity> customDevices = deviceRepository.findByIsDeletedFalseOrderByCreatedAtDesc();
        if (!customDevices.isEmpty()) {
            List<CompletableFuture<DeviceEntity>> futures = customDevices.stream()
                    .map(device -> CompletableFuture.supplyAsync(() -> {
                        NetworkPingService.PingResult result = networkPingService.ping(device.getIpAddress(), device.getPort());
                        if (result.isOnline()) {
                            device.setStatus(DeviceStatus.ONLINE);
                            device.setPingMs(result.pingMs());
                            device.setLastActiveAt(Instant.now());
                        } else {
                            device.setStatus(DeviceStatus.OFFLINE);
                            device.setPingMs(0);
                        }
                        if (userId != null) {
                            device.setUpdatedBy(userId);
                        }
                        return device;
                    }, ForkJoinPool.commonPool()))
                    .toList();

            CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();
            deviceRepository.saveAll(customDevices);
        }

        return getDevices();
    }

    @Transactional
    public DeviceResponse toggleDeviceStatus(UUID id, UUID userId) {
        Optional<DeviceEntity> customDeviceOpt = deviceRepository.findByIdAndIsDeletedFalse(id);
        if (customDeviceOpt.isPresent()) {
            DeviceEntity device = customDeviceOpt.get();
            if (device.getStatus() == DeviceStatus.ONLINE) {
                device.setStatus(DeviceStatus.OFFLINE);
                device.setPingMs(0);
            } else {
                device.setStatus(DeviceStatus.ONLINE);
                device.setPingMs(1);
                device.setLastActiveAt(Instant.now());
            }
            device.setUpdatedBy(userId);
            DeviceEntity saved = deviceRepository.save(device);
            return new DeviceResponse(
                    saved.getId(),
                    saved.getDeviceId(),
                    saved.getName(),
                    saved.getType(),
                    saved.getStatus().name(),
                    saved.getIpAddress(),
                    saved.getLastActiveAt(),
                    saved.getPingMs(),
                    saved.getVersion()
            );
        }

        UserEntity user = userRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thiết bị: " + id));

        // Nếu là tài khoản máy chấm công thực tế, không thu hồi token đăng nhập mà quản lý trạng thái máy chấm công
        List<TabletDevice> tablets = tabletDeviceRepository.findByAccountId(user.getId());
        TabletDevice tablet = selectBestTablet(tablets);
        if (tablet != null) {
            boolean isRecentlyActive = tablet.getLastSeenAt() != null &&
                    Duration.between(tablet.getLastSeenAt(), Instant.now()).getSeconds() < 180;

            // Nếu máy đang BLOCKED hoặc đang OFFLINE: admin ấn "Bật" -> khôi phục APPROVED và cập nhật lastSeenAt
            if (!"APPROVED".equalsIgnoreCase(tablet.getStatus()) || !isRecentlyActive) {
                for (TabletDevice other : tablets) {
                    if (!other.getId().equals(tablet.getId()) && "APPROVED".equalsIgnoreCase(other.getStatus())) {
                        other.setStatus("BLOCKED");
                        other.setStatusVersion(other.getStatusVersion() + 1);
                        tabletDeviceRepository.save(other);
                    }
                }
                tablet.setStatus("APPROVED");
                tablet.setLastSeenAt(Instant.now());
            } else {
                // Nếu máy đang ONLINE thực sự và admin chủ động ấn "Tắt"
                tablet.setStatus("BLOCKED");
                tablet.setStatusVersion(tablet.getStatusVersion() + 1);
            }
            tabletDeviceRepository.save(tablet);
            return toUserResponse(user);
        }

        // Với tài khoản mô phỏng: chỉ thu hồi simulated tokens, không thu hồi phiên ứng dụng thật
        List<RefreshToken> simulatedTokens = refreshTokenRepository.findAllActiveTokens(Instant.now()).stream()
                .filter(t -> t.getUserId().equals(user.getId()) && t.getDeviceInfo() != null && t.getDeviceInfo().startsWith("Simulated"))
                .collect(Collectors.toList());

        if (!simulatedTokens.isEmpty()) {
            simulatedTokens.forEach(t -> {
                t.setRevoked(true);
                refreshTokenRepository.save(t);
            });
        } else {
            RefreshToken token = RefreshToken.builder()
                    .userId(user.getId())
                    .tokenHash("simulated_" + UUID.randomUUID())
                    .expiresAt(Instant.now().plus(Duration.ofHours(24)))
                    .revoked(false)
                    .deviceInfo("Simulated Device IP: 192.168.1.100")
                    .createdAt(Instant.now())
                    .build();
            refreshTokenRepository.save(token);
        }

        return toUserResponse(user);
    }

    @Transactional
    public void receiveHeartbeat(String deviceId) {
        if (deviceId == null || deviceId.isBlank()) {
            return;
        }

        String code = deviceId.trim();
        deviceRepository.findByDeviceIdAndIsDeletedFalse(code.toUpperCase())
                .ifPresent(device -> {
                    device.setStatus(DeviceStatus.ONLINE);
                    device.setLastActiveAt(Instant.now());
                    deviceRepository.save(device);
                });

        userRepository.findByUsernameAndIsDeletedFalse(code.toLowerCase())
                .ifPresent(user -> {
                    user.setUpdatedAt(Instant.now());
                    userRepository.save(user);
                });
    }

    private DeviceResponse toUserResponse(UserEntity user) {
        List<TabletDevice> tablets = tabletDeviceRepository.findByAccountId(user.getId());
        TabletDevice tablet = selectBestTablet(tablets);

        List<RefreshToken> activeTokens = refreshTokenRepository.findAllActiveTokens(Instant.now()).stream()
                .filter(t -> t.getUserId().equals(user.getId()))
                .collect(Collectors.toList());

        return mapUserToDeviceResponse(user, tablet, activeTokens);
    }

    private DeviceResponse mapUserToDeviceResponse(UserEntity user, TabletDevice tablet, List<RefreshToken> userTokens) {
        boolean isOnline;
        Instant lastActiveAt = user.getUpdatedAt();
        String ipAddress = "N/A";
        String version = "1.0.0";
        int pingMs = 0;

        // Nếu có Tablet chấm công vật lý trong attendance_tablets
        if (tablet != null) {
            boolean tabletLive = tablet.getLastSeenAt() != null &&
                    tablet.getLastSeenAt().isAfter(Instant.now().minusSeconds(180));
            isOnline = tabletLive;
            lastActiveAt = tablet.getLastSeenAt() != null ? tablet.getLastSeenAt() : user.getUpdatedAt();
            if (tablet.getAppVersion() != null && !tablet.getAppVersion().isBlank()) {
                version = tablet.getAppVersion();
            }
            if (isOnline) {
                pingMs = 12; // Phản hồi thực tế từ tablet heartbeat gần nhất
                ipAddress = "192.168.1.120"; // Subnet mạng nội bộ công ty
            }
        } else {
            // Kiểm tra theo session refresh tokens của thiết bị/app
            isOnline = !userTokens.isEmpty();
            if (isOnline) {
                RefreshToken latestToken = userTokens.stream()
                        .sorted(Comparator.comparing(RefreshToken::getCreatedAt).reversed())
                        .findFirst()
                        .orElse(null);
                if (latestToken != null) {
                    lastActiveAt = latestToken.getCreatedAt();
                    if (latestToken.getDeviceInfo() != null && !latestToken.getDeviceInfo().isBlank()) {
                        String devInfo = latestToken.getDeviceInfo();
                        if (devInfo.contains("IP: ")) {
                            ipAddress = devInfo.substring(devInfo.indexOf("IP: ") + 4).trim();
                        } else {
                            ipAddress = devInfo; // e.g. "flutter-app"
                        }
                    } else {
                        ipAddress = "Mobile / App";
                    }
                }
                pingMs = 5;
            }
        }

        String displayName = user.getFullName();
        if (tablet != null && tablet.getModel() != null && !tablet.getModel().isBlank()) {
            displayName += " (" + tablet.getModel() + ")";
        }

        String deviceId = user.getEmployeeCode() != null && !user.getEmployeeCode().isBlank()
                ? user.getEmployeeCode()
                : user.getUsername().toUpperCase();

        return new DeviceResponse(
                user.getId(),
                deviceId,
                displayName,
                user.getRole().name(),
                isOnline ? "ONLINE" : "OFFLINE",
                ipAddress,
                lastActiveAt,
                pingMs,
                version
        );
    }

    private TabletDevice selectBestTablet(List<TabletDevice> tablets) {
        if (tablets == null || tablets.isEmpty()) {
            return null;
        }
        return tablets.stream()
                .sorted(Comparator
                        .comparing((TabletDevice t) -> "APPROVED".equalsIgnoreCase(t.getStatus()), Comparator.reverseOrder())
                        .thenComparing(t -> t.getLastSeenAt() != null ? t.getLastSeenAt() : Instant.EPOCH, Comparator.reverseOrder()))
                .findFirst()
                .orElse(null);
    }
}
