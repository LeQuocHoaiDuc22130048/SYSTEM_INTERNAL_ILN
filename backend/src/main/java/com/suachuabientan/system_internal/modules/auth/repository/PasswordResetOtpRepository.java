package com.suachuabientan.system_internal.modules.auth.repository;

import com.suachuabientan.system_internal.modules.auth.entity.PasswordResetOtp;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface PasswordResetOtpRepository extends JpaRepository<PasswordResetOtp, UUID> {
    Optional<PasswordResetOtp> findFirstByUserIdAndUsedFalseOrderByCreatedAtDesc(UUID userId);

    @Modifying
    @Query("UPDATE PasswordResetOtp o SET o.used = true WHERE o.userId = :userId AND o.used = false")
    void invalidateActiveForUser(@Param("userId") UUID userId);
}
