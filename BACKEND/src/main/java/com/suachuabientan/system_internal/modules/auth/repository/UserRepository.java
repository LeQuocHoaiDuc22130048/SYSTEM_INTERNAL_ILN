package com.suachuabientan.system_internal.modules.auth.repository;

import com.suachuabientan.system_internal.common.enums.UserStatus;
import com.suachuabientan.system_internal.modules.auth.domain.UserEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<UserEntity, UUID> {

    Optional<UserEntity> findByUsernameAndIsDeletedFalse(String username);

    Optional<UserEntity> findByEmailAndIsDeletedFalse(String email);

    Optional<UserEntity> findByIdAndIsDeletedFalse(UUID id);

    boolean existsByUsernameAndIsDeletedFalse(String username);

    boolean existsByEmailAndIsDeletedFalse(String email);

    boolean existsByEmployeeCodeAndIsDeletedFalse(String employeeCode);

    /**
     * Danh sách user đang chờ duyệt — chỉ ADMIN/MANAGER mới xem được (SEC-03).
     */
    Page<UserEntity> findByStatusAndIsDeletedFalse(UserStatus status, Pageable pageable);

    /**
     * Tìm kiếm nhân viên theo tên hoặc mã nhân viên.
     */
    @Query("""
            SELECT u FROM UserEntity u
            WHERE u.isDeleted = false
              AND (:keyword IS NULL
                   OR LOWER(u.fullName) LIKE LOWER(CONCAT('%', :keyword, '%'))
                   OR LOWER(u.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%'))
                   OR LOWER(u.email) LIKE LOWER(CONCAT('%', :keyword, '%')))
            """)
    Page<UserEntity> searchUsers(@Param("keyword") String keyword, Pageable pageable);
}
