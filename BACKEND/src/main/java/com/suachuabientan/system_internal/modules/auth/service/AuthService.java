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
import com.suachuabientan.system_internal.modules.auth.dto.request.ForgotPasswordRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.LoginRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RefreshTokenRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RegisterRequest;
import com.suachuabientan.system_internal.modules.auth.dto.request.RequestPasswordResetOtpRequest;
import com.suachuabientan.system_internal.modules.auth.dto.response.LoginResponse;
import com.suachuabientan.system_internal.modules.auth.dto.response.UserResponse;
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
    public void deleteUser(UUID targetUserId, UUID performedByUserId) {
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException(STR."Không tìm thấy nhân viên: \{targetUserId}"));

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
