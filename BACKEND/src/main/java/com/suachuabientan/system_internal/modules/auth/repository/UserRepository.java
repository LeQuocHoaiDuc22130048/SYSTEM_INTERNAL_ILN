package com.suachuabientan.system_internal.modules.auth.repository;

import com.suachuabientan.system_internal.modules.auth.domain.UserEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<UserEntity, String> {

    //Tìm kiếm người dùng bằng username
    Optional<UserEntity> findByUsername(String username);

    boolean existsByUsername(String username);
}
