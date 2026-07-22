package com.suachuabientan.system_internal.modules.device.service;

import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.auth.entity.RefreshToken;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.modules.auth.repository.RefreshTokenRepository;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.device.dto.DeviceRequest;
import com.suachuabientan.system_internal.modules.device.dto.DeviceResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DeviceService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final Random random = new Random();

    @Transactional(readOnly = true)
    public List<DeviceResponse> getDevices() {
        // Query users representing technician, warehouse, and attendance roles
        List<UserRole> deviceRoles = List.of(UserRole.TECHNICIAN, UserRole.WAREHOUSE, UserRole.ATTENDANCE);
        List<UserEntity> deviceUsers = userRepository.findByRoleInAndStatusAndIsDeletedFalse(
                deviceRoles, UserStatus.ACTIVE);

        // Query users who have logged in (have refresh token entries)
        List<UUID> loggedInUserIds = refreshTokenRepository.findDistinctUserIds();
        List<UserEntity> loggedInUsers = userRepository.findAllById(loggedInUserIds).stream()
                .filter(u -> u.getStatus() == UserStatus.ACTIVE && !Boolean.TRUE.equals(u.getIsDeleted()))
                .collect(Collectors.toList());

        // Merge users while preserving uniqueness
        Map<UUID, UserEntity> userMap = new LinkedHashMap<>();
        for (UserEntity user : deviceUsers) {
            userMap.put(user.getId(), user);
        }
        for (UserEntity user : loggedInUsers) {
            userMap.put(user.getId(), user);
        }

        // Pre-fetch active tokens for fast lookups
        List<RefreshToken> activeTokens = refreshTokenRepository.findAllActiveTokens(Instant.now());
        Map<UUID, List<RefreshToken>> activeTokensMap = activeTokens.stream()
                .collect(Collectors.groupingBy(RefreshToken::getUserId));

        return userMap.values().stream()
                .map(user -> toResponseWithFlicker(user, activeTokensMap.getOrDefault(user.getId(), Collections.emptyList())))
                .collect(Collectors.toList());
    }

    @Transactional
    public DeviceResponse createDevice(DeviceRequest request, UUID userId) {
        if (userRepository.existsByUsernameAndIsDeletedFalse(request.deviceId().toLowerCase())) {
            throw new IllegalArgumentException("Mã thiết bị (username) đã tồn tại trong hệ thống");
        }

        UserRole role = UserRole.valueOf(request.type());

        UserEntity user = UserEntity.builder()
                .username(request.deviceId().toLowerCase())
                .passwordHash("$2a$12$Rpx7gTteCym9U8.OpxZ09.9Vw/H9r2NspxK3jFjK.U6n/O.9yR2mO") // default dummy
                .fullName(request.name())
                .role(role)
                .status(UserStatus.ACTIVE)
                .employeeCode(request.deviceId())
                .department(role.name())
                .faceEnrolled(false)
                .build();
        user.setCreatedBy(userId);
        user.setUpdatedBy(userId);

        UserEntity savedUser = userRepository.save(user);

        return toResponse(savedUser);
    }

    @Transactional
    public DeviceResponse updateDevice(UUID id, DeviceRequest request, UUID userId) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thiết bị"));

        if (!user.getUsername().equals(request.deviceId().toLowerCase()) && 
                userRepository.existsByUsernameAndIsDeletedFalse(request.deviceId().toLowerCase())) {
            throw new IllegalArgumentException("Mã thiết bị (username) đã tồn tại trong hệ thống");
        }

        user.setFullName(request.name());
        user.setRole(UserRole.valueOf(request.type()));
        user.setEmployeeCode(request.deviceId());
        user.setUpdatedBy(userId);

        UserEntity savedUser = userRepository.save(user);

        return toResponse(savedUser);
    }

    @Transactional
    public void deleteDevice(UUID id, UUID userId) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thiết bị"));

        // Revoke active sessions
        refreshTokenRepository.revokeAllByUserId(user.getId());
        
        // Soft delete user
        user.softDelete(userId);
        userRepository.save(user);
    }

    @Transactional
    public DeviceResponse toggleDeviceStatus(UUID id, UUID userId) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thiết bị"));

        long activeCount = refreshTokenRepository.countActiveSessionsByUserId(user.getId(), Instant.now());
        boolean isOnline = activeCount > 0;

        if (isOnline) {
            // Revoke sessions
            refreshTokenRepository.revokeAllByUserId(user.getId());
        } else {
            // Create a simulated active refresh token
            RefreshToken token = RefreshToken.builder()
                    .userId(user.getId())
                    .tokenHash("simulated_" + UUID.randomUUID())
                    .expiresAt(Instant.now().plus(java.time.Duration.ofHours(24)))
                    .revoked(false)
                    .deviceInfo("Simulated Device IP: 192.168.1.100")
                    .createdAt(Instant.now())
                    .build();
            refreshTokenRepository.save(token);
        }

        return toResponse(user);
    }

    @Transactional
    public DeviceResponse pingDevice(UUID id, UUID userId) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thiết bị"));

        long activeCount = refreshTokenRepository.countActiveSessionsByUserId(user.getId(), Instant.now());
        if (activeCount == 0) {
            // Bring online
            RefreshToken token = RefreshToken.builder()
                    .userId(user.getId())
                    .tokenHash("simulated_" + UUID.randomUUID())
                    .expiresAt(Instant.now().plus(java.time.Duration.ofHours(24)))
                    .revoked(false)
                    .deviceInfo("Simulated Device IP: 192.168.1.100")
                    .createdAt(Instant.now())
                    .build();
            refreshTokenRepository.save(token);
        } else {
            // Touch existing sessions by saving a dummy or just returning
            user.setUpdatedAt(Instant.now());
            userRepository.save(user);
        }

        return toResponse(user);
    }

    @Transactional
    public void receiveHeartbeat(String deviceId) {
        Optional<UserEntity> userOpt = userRepository.findByUsernameAndIsDeletedFalse(deviceId.toLowerCase());
        if (userOpt.isPresent()) {
            UserEntity user = userOpt.get();
            long activeCount = refreshTokenRepository.countActiveSessionsByUserId(user.getId(), Instant.now());
            if (activeCount == 0) {
                RefreshToken token = RefreshToken.builder()
                        .userId(user.getId())
                        .tokenHash("simulated_" + UUID.randomUUID())
                        .expiresAt(Instant.now().plus(java.time.Duration.ofHours(24)))
                        .revoked(false)
                        .deviceInfo("Physical Heartbeat IP: 192.168.1.120")
                        .createdAt(Instant.now())
                        .build();
                refreshTokenRepository.save(token);
            }
        }
    }

    private DeviceResponse toResponse(UserEntity user) {
        List<RefreshToken> activeTokens = refreshTokenRepository.findAllActiveTokens(Instant.now()).stream()
                .filter(t -> t.getUserId().equals(user.getId()))
                .collect(Collectors.toList());
        return toResponse(user, activeTokens);
    }

    private DeviceResponse toResponse(UserEntity user, List<RefreshToken> userActiveTokens) {
        List<RefreshToken> activeTokens = userActiveTokens.stream()
                .filter(RefreshToken::isValid)
                .sorted(Comparator.comparing(RefreshToken::getCreatedAt).reversed())
                .collect(Collectors.toList());

        boolean isOnline = !activeTokens.isEmpty();
        String status = isOnline ? "ONLINE" : "OFFLINE";
        
        String ipAddress = "N/A";
        Instant lastActiveAt = user.getUpdatedAt();
        Integer pingMs = 0;

        if (isOnline) {
            RefreshToken latestToken = activeTokens.get(0);
            if (latestToken.getDeviceInfo() != null && !latestToken.getDeviceInfo().isBlank()) {
                ipAddress = latestToken.getDeviceInfo().replace("Simulated Device IP: ", "").replace("Physical Heartbeat IP: ", "");
            } else {
                ipAddress = "192.168.1.50";
            }
            lastActiveAt = latestToken.getCreatedAt();
            pingMs = random.nextInt(35) + 5;
        }

        return new DeviceResponse(
                user.getId(),
                user.getEmployeeCode() != null ? user.getEmployeeCode() : user.getUsername().toUpperCase(),
                user.getFullName(),
                user.getRole().name(),
                status,
                ipAddress,
                lastActiveAt,
                pingMs,
                "1.0.0"
        );
    }

    private DeviceResponse toResponseWithFlicker(UserEntity user) {
        return toResponseWithFlicker(user, Collections.emptyList());
    }

    private DeviceResponse toResponseWithFlicker(UserEntity user, List<RefreshToken> userActiveTokens) {
        DeviceResponse response = toResponse(user, userActiveTokens);
        if ("ONLINE".equals(response.status())) {
            int ping = Math.max(2, response.pingMs() + (random.nextInt(7) - 3));
            return new DeviceResponse(
                    response.id(),
                    response.deviceId(),
                    response.name(),
                    response.type(),
                    response.status(),
                    response.ipAddress(),
                    response.lastActiveAt(),
                    ping,
                    response.version()
            );
        }
        return response;
    }
}
