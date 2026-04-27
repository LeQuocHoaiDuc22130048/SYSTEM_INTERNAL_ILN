package com.suachuabientan.system_internal.modules.auth.repository;

import com.suachuabientan.system_internal.modules.auth.domain.RefreshToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    Optional<RefreshToken> findByToken(String token);

    void deleteByUser_Id(String userId);

    void deleteByToken(String token);
}