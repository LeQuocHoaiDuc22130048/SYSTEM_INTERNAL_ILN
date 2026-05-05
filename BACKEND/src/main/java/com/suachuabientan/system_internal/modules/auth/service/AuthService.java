package com.suachuabientan.system_internal.modules.auth.service;

import com.suachuabientan.system_internal.common.enums.ApprovalAction;
import com.suachuabientan.system_internal.common.enums.UserRole;
import com.suachuabientan.system_internal.common.enums.UserStatus;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.common.util.EmployeeCodeGenerator;
import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.modules.auth.domain.RefreshToken;
import com.suachuabientan.system_internal.modules.auth.domain.UserEntity;
import com.suachuabientan.system_internal.modules.auth.domain.UserRegistrationRequestEntity;
import com.suachuabientan.system_internal.modules.auth.dto.request.ApproveUserRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.LoginRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RefreshTokenRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RegisterRequest;
import com.suachuabientan.system_internal.modules.auth.dto.response.LoginResponse;
import com.suachuabientan.system_internal.modules.auth.dto.response.UserResponse;
import com.suachuabientan.system_internal.modules.auth.mapper.UserMapper;
import com.suachuabientan.system_internal.modules.auth.repository.RefreshTokenRepository;
import com.suachuabientan.system_internal.modules.auth.repository.UserRegistrationRequestRepository;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final UserMapper userMapper;
    private final EmployeeCodeGenerator employeeCodeGenerator;
    private final AuthenticationManager authenticationManager;
    private final JwtUtil jwtUtil;
    private final RefreshTokenRepository refreshTokenRepository;
    private final UserRegistrationRequestRepository userRegistrationRequestRepository;

    /**
     * Đăng ký tài khoản mới — trạng thái PENDING_APPROVAL, chưa được login (SEC-03).
     */

    @Transactional
    public UserResponse register(RegisterRequest request) {
        if (userRepository.existsByUsernameAndIsDeletedFalse(request.username())) {
            throw new BusinessException("Tên đăng nhập " + request.username() + "' đã tồn tại", 409);
        }


        String employeeCode = employeeCodeGenerator.generate(request.department());

        UserEntity user = UserEntity.builder()
                .username(request.username())
                .passwordHash(passwordEncoder.encode(request.password()))
                .fullName(request.fullName())
                .employeeCode(employeeCode)
                .department(request.department())
                .phone(request.phone())
                .role(UserRole.EMPLOYEE)
                .status(UserStatus.PENDING_APPROVAL)
                .faceEnrolled(false)
                .build();



        UserEntity saved = userRepository.save(user);
        log.info("Tài khoản mới đăng ký: username={}", saved.getUsername());

        return userMapper.toResponse(saved);
    }

    /**
     * Đăng nhập — chỉ tài khoản ACTIVE mới được login (SEC-03).
     */
    @Transactional
    public LoginResponse login(LoginRequest request) {
        authenticationManager.authenticate(
                new org.springframework.security.authentication.UsernamePasswordAuthenticationToken(
                        request.username(), request.password()
                )
        );

        UserEntity user = userRepository.findByUsernameAndIsDeletedFalse(request.username())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng"));

        if (!user.isActive()) {
            throw new BusinessException(buildLoginBlockMessage(user.getStatus()), 403);
        }

        String accessToken = jwtUtil.generateAccessToken(
                user.getId(), user.getUsername(), user.getRole().name());
        String refreshToken = jwtUtil.generateRefreshToken(user.getId());
        saveRefreshToken(user.getId(), refreshToken, request.deviceInfo());

        log.info("Đăng nhập thành công: userId={}, role={}", user.getId(), user.getRole());

        return new LoginResponse(
                accessToken, refreshToken, "Bearer", 900L,
                new LoginResponse.UserInfo(user.getId(), user.getUsername(), user.getFullName(),
                        user.getRole().name(), user.getStatus().name(),
                        user.getAvatarUrl(), user.getDepartment())
        );
    }

    /**
     * Refresh token — kiểm tra refresh token hợp lệ và chưa hết hạn, sau đó cấp mới access token (SEC-03).
     */
    @Transactional
    public LoginResponse refreshToken(RefreshTokenRequest request) {
        String rawToken = request.refreshToken();

        if (!jwtUtil.isTokenValid(rawToken) || !jwtUtil.isRefreshToken(rawToken))
            throw new BusinessException("Refresh token không hợp lệ hoặc đã hết hạn", 401);

        String tokenHash = jwtUtil.hashToken(rawToken);
        RefreshToken storedToken = refreshTokenRepository.findByTokenHashAndRevokedFalse(tokenHash)
                .orElseThrow(() -> new BusinessException("Refresh token không hợp lệ hoặc đã bị thu hồi", 401));

        if (!storedToken.isValid()) throw new BusinessException("Refresh token đã hết hạn", 401);

        UUID userId = jwtUtil.extractUserId(rawToken);

        UserEntity user = userRepository.findByIdAndIsDeletedFalse(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng"));

        if (!user.isActive())
            throw new BusinessException("Tài khoản đã bị khóa", 403);

        storedToken.revoke();
        refreshTokenRepository.save(storedToken);

        String newAccessToken = jwtUtil.generateAccessToken(
                user.getId(), user.getUsername(), user.getRole().name());

        String newRefreshToken = jwtUtil.generateRefreshToken(user.getId());
        saveRefreshToken(user.getId(), newRefreshToken, storedToken.getDeviceInfo());

        return buildLoginResponse(newAccessToken, newRefreshToken, user);
    }


    /**
     * Logout — revoke refresh token hiện tại.
     */
    @Transactional
    public void logout(String rawRefreshToken) {
        String tokenHash = jwtUtil.hashToken(rawRefreshToken);
        refreshTokenRepository.findByTokenHashAndRevokedFalse(tokenHash).
                ifPresent(t -> {
                    t.revoke();
                    refreshTokenRepository.save(t);
                    log.info("Logout: revoke tokenid={}", t.getId());
                });
    }

    /**
     * Logout tất cả thiết bị — revoke toàn bộ refresh token của user.
     */

    @Transactional
    public void logoutAllDevices(UUID userId) {
        refreshTokenRepository.revokeAllByUserId(userId);
        log.info("Logout all devices: userId={}", userId);
    }

    // ── Approve / Reject ──────────────────────────────────────────────────
    /**
     * Duyệt hoặc từ chối tài khoản nhân viên.
     * Chỉ ADMIN và MANAGER mới có quyền — kiểm tra tại Controller qua @PreAuthorize.
     */
    @Transactional
    public UserResponse processUserApproval(UUID targetUserId, ApproveUserRequest request, UUID reviewerUserId) {
        UserEntity target = userRepository.findByIdAndIsDeletedFalse(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng " + targetUserId));

        if(!target.isPending()) throw new BusinessException("Tài khoản không ở trạng thái chờ duyệt");

        if (request.action() == ApprovalAction.APPROVE) {
            target.approve(reviewerUserId);
            log.info("Process user approval: userId={}", targetUserId);
        } else {
            if (!StringUtils.hasText(request.note())) throw new BusinessException("Lý do từ chối không được để trống");

            target.reject(reviewerUserId, request.note());
            log.info("Từ chối tài khoản: userId={}, rejectedBy={}, reason={}", targetUserId, reviewerUserId, request.note());
        }

        //ghi vào history
        UserRegistrationRequestEntity history = UserRegistrationRequestEntity.builder()
                .userId(targetUserId)
                .action(request.action().name())
                .reviewedBy(reviewerUserId)
                .note(request.note())
                .reviewedAt(Instant.now())
                .build();

        userRegistrationRequestRepository.save(history);

        return userMapper.toResponse(userRepository.save(target));
    }

    // ── Query ─────────────────────────────────────────────────────────────

    /**
     * Danh sách tài khoản đang chờ duyệt — phân trang (SEC-03).
     */
    @Transactional(readOnly = true)
    public Page<UserResponse> getPendingUsers(Pageable pageable) {
        return userRepository.findByStatusAndIsDeletedFalse(UserStatus.PENDING_APPROVAL, pageable)
                .map(userMapper::toResponse);
    }


    /**
     * Tìm kiếm nhân viên — phân trang, có keyword.
     */
    @Transactional(readOnly = true)
    public Page<UserResponse> searchUsers(String keyword, Pageable pageable) {
        String kw = (keyword == null || keyword.trim().isEmpty() ? null : keyword.trim());
        return userRepository.searchUsers(kw, pageable)
                .map(userMapper::toResponse);
    }

    /**
     * Danh sách nhân viên
     */
    @Transactional(readOnly = true)
    public Page<UserResponse> getUsers(Pageable pageable) {
        List<UserStatus> statuses = List.of(UserStatus.ACTIVE, UserStatus.SUSPENDED);
        return userRepository.findByStatusInAndIsDeletedFalse(statuses, pageable)
                .map(userMapper::toResponse);
    }

    @Transactional(readOnly = true)
    public UserResponse getUserById(UUID userId) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên: " + userId));
        return userMapper.toResponse(user);
    }

    // ── Suspend / Delete ──────────────────────────────────────────────────

    @Transactional
    public UserResponse suspendUser(UUID targetUserId, UUID performedByUserId) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên: " + targetUserId));

        user.suspend();
        log.info("Khoá tài khoản: userId={}, by={}", targetUserId, performedByUserId);
        return userMapper.toResponse(userRepository.save(user));
    }

    @Transactional
    public UserResponse unsuspendUser(UUID targetUserId, UUID performedByUserId) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên: " + targetUserId));

        if (user.getStatus() != UserStatus.SUSPENDED) {
            throw new BusinessException("Chỉ có thể mở khóa tài khoản đang bị khóa");
        }

        user.activate();
        log.info("Mở khóa tài khoản: userId={}, by={}", targetUserId, performedByUserId);
        return userMapper.toResponse(userRepository.save(user));
    }

    @Transactional
    public void deleteUser(UUID targetUserId, UUID performedByUserId) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên: " + targetUserId));

        // Soft delete — không xóa thật (DB rules)
        user.softDelete(performedByUserId);
        user.setStatus(UserStatus.DELETED);
        userRepository.save(user);
        log.info("Xoá tài khoản (soft): userId={}, by={}", targetUserId, performedByUserId);
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    private String buildLoginBlockMessage(UserStatus status) {
        return switch (status) {
            case PENDING_APPROVAL -> "Tài khoản chưa được duyệt. Vui lòng liên hệ quản lý.";
            case SUSPENDED -> "Tài khoản đã bị tạm khoá. Vui lòng liên hệ Admin.";
            case DELETED -> "Tài khoản không tồn tại.";
            case REGISTERED -> "Tài khoản chưa hoàn tất đăng ký.";
            default -> "Không thể đăng nhập. Vui lòng liên hệ hỗ trợ.";
        };
    }

    private void saveRefreshToken(UUID id, String newRefreshToken, String deviceInfo) {
        RefreshToken token = RefreshToken.builder()
                .userId(id)
                .tokenHash(jwtUtil.hashToken(newRefreshToken))
                .expiresAt(Instant.now().plusMillis(jwtUtil.getRefreshTokenExpiration()))
                .revoked(false)
                .deviceInfo(deviceInfo)
                .createdAt(Instant.now())
                .build();
        refreshTokenRepository.save(token);
    }

    private LoginResponse buildLoginResponse(String newAccessToken, String newRefreshToken, UserEntity user) {
        return new LoginResponse(
                newAccessToken,
                newRefreshToken,
                "Bearer",
                900L,
                new LoginResponse.UserInfo(
                        user.getId(),
                        user.getUsername(),
                        user.getFullName(),
                        user.getRole().name(),
                        user.getStatus().name(),
                        user.getAvatarUrl(),
                        user.getDepartment()
                )
        );
    }
}
