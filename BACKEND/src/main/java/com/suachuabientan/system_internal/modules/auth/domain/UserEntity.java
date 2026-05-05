package com.suachuabientan.system_internal.modules.auth.domain;

import com.suachuabientan.system_internal.common.enums.UserRole;
import com.suachuabientan.system_internal.common.enums.UserStatus;
import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "users")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserEntity extends BaseEntity {

    // ── Thông tin đăng nhập ───────────────────────────────────────────────

    @Column(nullable = false, unique = true, length = 50)
    private String username;



    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    // ── Thông tin cá nhân (bắt buộc) ─────────────────────────────────────

    @Column(name = "full_name", nullable = false, length = 100)
    private String fullName;

    /**
     * Mã nhân viên — format: {DeptCode}-{YYYY}-{NNN}
     * VD: IT-2024-001, KHO-2024-005
     */
    @Column(name = "employee_code", unique = true, length = 30)
    private String employeeCode;

    @Column(length = 100)
    private String department;

    @Column(length = 20)
    private String phone;

    // ── Thông tin cá nhân (tùy chọn - nhạy cảm) ──────────────────────────

    /** CCCD — lưu dạng AES-256 encrypted */
    @Column(name = "national_id", length = 500)
    private String nationalId;

    /** Ngày sinh — lưu dạng LocalDate */
    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Column(columnDefinition = "TEXT")
    private String address;

    // ── Phân quyền & trạng thái ───────────────────────────────────────────

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(nullable = false, columnDefinition = "user_role")
    private UserRole role = UserRole.EMPLOYEE;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(nullable = false, columnDefinition = "user_status")
    private UserStatus status = UserStatus.PENDING_APPROVAL;

    // ── Duyệt tài khoản ───────────────────────────────────────────────────

    @Column(name = "approved_by")
    private UUID approvedBy;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(name = "rejection_reason", columnDefinition = "TEXT")
    private String rejectionReason;

    // ── Chấm công khuôn mặt ───────────────────────────────────────────────

    /** JSON vector từ DeepFace/ML Kit — không lưu ảnh gốc */
    @Column(name = "face_encoding", columnDefinition = "TEXT")
    private String faceEncoding;

    @Column(name = "face_enrolled", nullable = false)
    private Boolean faceEnrolled = false;

    @Column(name = "face_verified_by")
    private UUID faceVerifiedBy;

    // ── Thông báo & avatar ────────────────────────────────────────────────

    /** Firebase FCM token — cập nhật mỗi lần login từ thiết bị mới */
    @Column(name = "device_token", length = 500)
    private String deviceToken;

    @Column(name = "avatar_url", length = 500)
    private String avatarUrl;

    // ── Helper methods ────────────────────────────────────────────────────

    public boolean isActive() {
        return UserStatus.ACTIVE.equals(this.status) && !Boolean.TRUE.equals(this.getIsDeleted());
    }

    public boolean isPending() {
        return UserStatus.PENDING_APPROVAL.equals(this.status);
    }

    public boolean canLogin() {
        return isActive();
    }

    public void approve(UUID approvedByUserId) {
        this.status = UserStatus.ACTIVE;
        this.approvedBy = approvedByUserId;
        this.approvedAt = Instant.now();
        this.rejectionReason = null;
    }

    public void reject(UUID rejectedByUserId, String reason) {
        this.status = UserStatus.REGISTERED;
        this.approvedBy = rejectedByUserId;
        this.approvedAt = Instant.now();
        this.rejectionReason = reason;
    }

    public void suspend() {
        this.status = UserStatus.SUSPENDED;
    }


}