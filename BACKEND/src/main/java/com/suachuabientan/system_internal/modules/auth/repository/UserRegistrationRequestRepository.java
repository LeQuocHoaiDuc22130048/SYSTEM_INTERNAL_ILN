package com.suachuabientan.system_internal.modules.auth.repository;

import com.suachuabientan.system_internal.modules.auth.domain.UserRegistrationRequestEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface UserRegistrationRequestRepository extends JpaRepository<UserRegistrationRequestEntity, UUID> {

}
