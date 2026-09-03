package com.suachuabientan.system_internal.modules.auth.service;

import com.suachuabientan.system_internal.modules.auth.enums.ApprovalAction;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.common.util.EmployeeCodeGenerator;
import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.modules.auth.entity.RefreshToken;
import com.suachuabientan.system_internal.modules.auth.entity.PasswordResetOtp;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.entity.UserRegistrationRequestEntity;
import com.suachuabientan.system_internal.modules.auth.dto.request.ApproveUserRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.ChangePasswordRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.DeleteAccountRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.ForgotPasswordRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.LoginRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RefreshTokenRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RegisterRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RequestPasswordResetOtpRequest;
import com.suachuabientan.system_internal.modules.auth.dto.response.LoginResponse;
import com.suachuabientan.system_internal.modules.auth.dto.response.UserResponse;
import com.suachuabientan.system_internal.modules.auth.dto.response.UserPermissionDetailResponse;
import com.suachuabientan.system_internal.modules.auth.mapper.UserMapper;
import com.suachuabientan.system_internal.modules.auth.repository.RefreshTokenRepository;
import com.suachuabientan.system_internal.modules.auth.repository.PasswordResetOtpRepository;
import com.suachuabientan.system_internal.modules.auth.repository.UserRegistrationRequestRepository;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
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
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.security.SecureRandom;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {
    private static final SecureRandom OTP_RANDOM = new SecureRandom();

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final UserMapper userMapper;
    private final EmployeeCodeGenerator employeeCodeGenerator;
    private final AuthenticationManager authenticationManager;
    private final JwtUtil jwtUtil;
    private final RefreshTokenRepository refreshTokenRepository;
    private final UserRegistrationRequestRepository userRegistrationRequestRepository;
    private final NotificationService notificationService;
    private final PasswordResetOtpRepository passwordResetOtpRepository;
    private final RbacService rbacService;

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


        UserEntity saved = userRepository.saveAndFlush(user);
        rbacService.ensurePrimaryRoleAssigned(saved.getId(), saved.getRole());
        notifyAccountPending(saved);
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

        List<String> permissions = permissionCodes(user);
        String accessToken = jwtUtil.generateAccessToken(
                user.getId(), user.getUsername(), user.getRole().name(), permissions);
        String refreshToken = jwtUtil.generateRefreshToken(user.getId());
        saveRefreshToken(user.getId(), refreshToken, request.deviceInfo());

        log.info("Đăng nhập thành công: userId={}, role={}", user.getId(), user.getRole());

        return new LoginResponse(
                accessToken, refreshToken, "Bearer", 900L,
                new LoginResponse.UserInfo(user.getId(), user.getUsername(), user.getFullName(),
                        user.getRole().name(), user.getStatus().name(),
                        user.getAvatarUrl(), user.getDepartment(), permissions)
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

        List<String> permissions = permissionCodes(user);
        String newAccessToken = jwtUtil.generateAccessToken(
                user.getId(), user.getUsername(), user.getRole().name(), permissions);

        String newRefreshToken = jwtUtil.generateRefreshToken(user.getId());
        saveRefreshToken(user.getId(), newRefreshToken, storedToken.getDeviceInfo());

        return buildLoginResponse(newAccessToken, newRefreshToken, user);
    }

    @Transactional
    public void requestPasswordResetOtp(RequestPasswordResetOtpRequest request) {
        UserEntity user = findPasswordResetUser(request.username(), request.phone());
        passwordResetOtpRepository.invalidateActiveForUser(user.getId());

        String otpCode = String.format("%06d", OTP_RANDOM.nextInt(1_000_000));
        passwordResetOtpRepository.save(PasswordResetOtp.builder()
                .userId(user.getId())
                .codeHash(passwordEncoder.encode(otpCode))
                .expiresAt(Instant.now().plus(5, ChronoUnit.MINUTES))
                .attempts(0)
                .used(false)
                .createdAt(Instant.now())
                .build());

        notificationService.sendToUser(
                user.getId(),
                NotificationType.PASSWORD_RESET_OTP,
                "Ma xac minh dat lai mat khau",
                "Ma OTP cua ban la " + otpCode + ". Ma co hieu luc trong 5 phut.",
                "PASSWORD_RESET",
                user.getId().toString(),
                true);
        log.info("Password reset OTP issued for userId={}", user.getId());
    }

    @Transactional
    public void forgotPassword(ForgotPasswordRequest request) {
        if (!request.newPassword().equals(request.confirmPassword())) {
            throw new BusinessException("Mat khau xac nhan khong khop", 400);
        }

        UserEntity user = findPasswordResetUser(request.username(), request.phone());
        PasswordResetOtp otp = passwordResetOtpRepository
                .findFirstByUserIdAndUsedFalseOrderByCreatedAtDesc(user.getId())
                .orElseThrow(() -> new BusinessException("Vui long yeu cau ma OTP moi", 400));

        if (!otp.isUsable()) {
            throw new BusinessException("Ma OTP khong con hieu luc. Vui long yeu cau ma moi", 400);
        }

        if (!passwordEncoder.matches(request.otp(), otp.getCodeHash())) {
            otp.setAttempts(otp.getAttempts() + 1);
            if (otp.getAttempts() >= 5) {
                otp.setUsed(true);
            }
            passwordResetOtpRepository.save(otp);
            throw new BusinessException("Ma OTP khong dung", 400);
        }

        otp.setUsed(true);
        passwordResetOtpRepository.save(otp);
        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
        userRepository.save(user);
        refreshTokenRepository.revokeAllByUserId(user.getId());
        log.info("Forgot password: reset password and revoked sessions for userId={}", user.getId());
    }

    @Transactional
    public void changePassword(UUID userId, ChangePasswordRequest request) {
        if (!request.newPassword().equals(request.confirmPassword())) {
            throw new BusinessException("Mat khau xac nhan khong khop", 400);
        }

        UserEntity user = userRepository.findByIdAndIsDeletedFalse(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay nguoi dung"));

        if (!passwordEncoder.matches(request.currentPassword(), user.getPasswordHash())) {
            throw new BusinessException("Mat khau hien tai khong dung", 400);
        }

        if (passwordEncoder.matches(request.newPassword(), user.getPasswordHash())) {
            throw new BusinessException("Mat khau moi phai khac mat khau hien tai", 400);
        }

        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
        userRepository.save(user);
        refreshTokenRepository.revokeAllByUserId(user.getId());
        notificationService.clearDeviceToken(user.getId());
        log.info("Changed password and revoked sessions for userId={}", user.getId());
    }

    private UserEntity findPasswordResetUser(String username, String phone) {
        UserEntity user = userRepository.findByUsernameAndIsDeletedFalse(username)
                .orElseThrow(() -> new ResourceNotFoundException("Khong tim thay nguoi dung"));

        if (user.getPhone() == null || !user.getPhone().equals(phone)) {
            throw new BusinessException("So dien thoai xac minh khong dung", 400);
        }
        return user;
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
                    notificationService.clearDeviceToken(t.getUserId());
                    log.info("Logout: revoke tokenid={}", t.getId());
                });
    }

    /**
     * Logout tất cả thiết bị — revoke toàn bộ refresh token của user.
     */

    @Transactional
    public void logoutAllDevices(UUID userId) {
        refreshTokenRepository.revokeAllByUserId(userId);
        notificationService.clearDeviceToken(userId);
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

        if (!target.isPending()) throw new BusinessException("Tài khoản không ở trạng thái chờ duyệt");

        boolean approved = request.action() == ApprovalAction.APPROVE;
        if (approved) {
            target.approve(reviewerUserId);
            rbacService.ensurePrimaryRoleAssigned(target.getId(), target.getRole());
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

        UserEntity saved = userRepository.save(target);
        notifyAccountDecision(saved, approved);
        return userMapper.toResponse(saved);
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

    @Transactional
    public void deleteMyAccount(UUID userId, DeleteAccountRequest request) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng"));

        // SUPER_ADMIN không được phép tự xóa trên app để tránh mất quyền quản trị tối cao
        if (UserRole.SUPER_ADMIN.equals(user.getRole())) {
            throw new BusinessException(
                    "Tài khoản Quản trị viên tối cao (SUPER_ADMIN) không thể tự xóa qua ứng dụng di động. Vui lòng liên hệ quản trị hệ thống.",
                    400
            );
        }

        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new BusinessException("Mật khẩu xác nhận không chính xác", 400);
        }

        // Thực hiện quy trình bảo mật: soft-delete, thu hồi token, xóa dữ liệu nhạy cảm
        user.softDelete(userId);
        user.setStatus(UserStatus.DELETED);
        user.setDeviceToken(null);
        user.setFaceEncoding(null);
        user.setFaceEnrolled(false);
        user.setFaceVerifiedBy(null);
        userRepository.save(user);

        refreshTokenRepository.revokeAllByUserId(user.getId());
        notificationService.clearDeviceToken(user.getId());

        log.warn("Tài khoản đã tự yêu cầu xóa và vô hiệu hóa thành công: userId={}, username={}, reason={}",
                user.getId(), user.getUsername(), request.reason());
    }

    @Transactional
    public void deleteUser(UUID targetUserId, UUID performedByUserId) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException(STR."Không tìm thấy nhân viên: \{targetUserId}"));

        // Soft delete — không xóa thật (DB rules)
        user.softDelete(performedByUserId);
        user.setStatus(UserStatus.DELETED);
        user.setDeviceToken(null);
        user.setFaceEncoding(null);
        user.setFaceEnrolled(false);
        user.setFaceVerifiedBy(null);
        userRepository.save(user);

        refreshTokenRepository.revokeAllByUserId(targetUserId);
        notificationService.clearDeviceToken(targetUserId);
        log.info("Xoá tài khoản (soft): userId={}, by={}", targetUserId, performedByUserId);
    }

    // ── User management ───────────────────────────────────────────────────

    /**
     * Danh sách tất cả user (có filter keyword) — chỉ ADMIN+ mới được xem.
     */
    @Transactional(readOnly = true)
    public Page<UserResponse> getUsers(String keyword, Pageable pageable) {
        return userRepository.searchUsers(keyword, pageable).map(userMapper::toResponse);
    }

    /**
     * Đổi role của user — chỉ SUPER_ADMIN mới có quyền.
     */
    @Transactional
    public UserResponse updateUserRole(UUID targetUserId, String newRoleStr, UUID performedByUserId) {
        UserRole newRole;
        try {
            newRole = UserRole.valueOf(newRoleStr.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new BusinessException("Role không hợp lệ: " + newRoleStr, 400);
        }

        UserEntity user = userRepository.findByIdAndIsDeletedFalse(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng: " + targetUserId));

        if (targetUserId.equals(performedByUserId)) {
            throw new BusinessException("Không thể tự đổi role của bản thân", 400);
        }

        user.setRole(newRole);
        rbacService.updateRole(targetUserId, newRole);
        UserEntity saved = userRepository.save(user);
        log.info("Cập nhật role: userId={}, newRole={}, by={}", targetUserId, newRole, performedByUserId);
        return userMapper.toResponse(saved);
    }

    /**
     * Suspend hoặc Activate tài khoản — ADMIN+ mới có quyền.
     */
    @Transactional
    public UserResponse updateUserStatus(UUID targetUserId, String action, UUID performedByUserId) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng: " + targetUserId));

        if (targetUserId.equals(performedByUserId)) {
            throw new BusinessException("Không thể tự thay đổi trạng thái tài khoản của bản thân", 400);
        }

        switch (action.toUpperCase()) {
            case "SUSPEND" -> {
                user.suspend();
                log.info("Tạm khóa tài khoản: userId={}, by={}", targetUserId, performedByUserId);
            }
            case "ACTIVATE" -> {
                user.activate();
                log.info("Kích hoạt tài khoản: userId={}, by={}", targetUserId, performedByUserId);
            }
            default -> throw new BusinessException("Action không hợp lệ: " + action + ". Dùng SUSPEND hoặc ACTIVATE", 400);
        }

        return userMapper.toResponse(userRepository.save(user));
    }

    /**
     * Lấy chi tiết permissions của user (từng quyền, nguồn gốc, override).
     */
    @Transactional(readOnly = true)
    public List<UserPermissionDetailResponse> getUserPermissions(UUID targetUserId) {
        userRepository.findByIdAndIsDeletedFalse(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng: " + targetUserId));

        return rbacService.getUserPermissionDetails(targetUserId).stream()
                .map(row -> {
                    boolean fromRole = Boolean.TRUE.equals(row.get("from_role"));
                    Boolean overrideGranted = (Boolean) row.get("override_granted");

                    boolean effective;
                    if (overrideGranted != null) {
                        effective = overrideGranted;
                    } else {
                        effective = fromRole;
                    }

                    return new UserPermissionDetailResponse(
                            (String) row.get("code"),
                            (String) row.get("name"),
                            (String) row.get("module"),
                            (String) row.get("description"),
                            fromRole,
                            overrideGranted,
                            effective
                    );
                })
                .toList();
    }

    /**
     * Cập nhật permission overrides của user.
     */
    @Transactional
    public List<UserPermissionDetailResponse> updateUserPermissions(
            UUID targetUserId,
            Map<String, Boolean> overrides,
            UUID performedByUserId) {

        userRepository.findByIdAndIsDeletedFalse(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng: " + targetUserId));

        if (targetUserId.equals(performedByUserId)) {
            throw new BusinessException("Không thể tự thay đổi quyền của bản thân", 400);
        }

        rbacService.setUserPermissionOverrides(targetUserId, overrides, performedByUserId);
        log.info("Cập nhật permissions: userId={}, overrides={}, by={}", targetUserId, overrides.keySet(), performedByUserId);

        return getUserPermissions(targetUserId);
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
                        user.getDepartment(),
                        permissionCodes(user)
                )
        );
    }

    private List<String> permissionCodes(UserEntity user) {
        List<String> permissions = rbacService.getPermissionCodes(user.getId());
        return permissions != null ? permissions : List.of();
    }

    private void notifyAccountPending(UserEntity user) {
        notificationService.sendToRoles(
                managerRoles(),
                NotificationType.ACCOUNT_PENDING,
                "Tài khoản mới cho duyệt",
                STR."\{user.getFullName()} vừa đăng ký tài khoản và đang chờ duyệt.",
                "USER",
                user.getId().toString(),
                false);
    }

    private void notifyAccountDecision(UserEntity user, boolean approved) {
        notificationService.sendToUser(
                user.getId(),
                approved ? NotificationType.ACCOUNT_APPROVED : NotificationType.ACCOUNT_REJECTED,
                approved ? "Tài khoản đã được duyệt" : "Tài khoản bị từ chối",
                approved
                       ? "Tài khoản của bạn đã được duyệt. Bạn có thể đăng nhập hệ thống."
                        : STR."Tài khoản của bạn bị từ chối. Lý do: \{user.getRejectionReason()}",
                "USER",
                user.getId().toString(),
                true);
    }

    private List<UserRole> managerRoles() {
        return List.of(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.MANAGER);
    }
}
