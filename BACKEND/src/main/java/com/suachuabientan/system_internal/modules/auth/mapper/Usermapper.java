package com.suachuabientan.system_internal.modules.auth.mapper;

import com.suachuabientan.system_internal.modules.auth.domain.UserEntity;
import com.suachuabientan.system_internal.modules.auth.dto.response.LoginResponse;
import com.suachuabientan.system_internal.modules.auth.dto.response.UserResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper(componentModel = "spring")
public interface UserMapper {
    //Ánh xạ thông thường
    UserResponse toResponse(UserEntity user);

    //Ánh xạ entity sang LoginResponse (DTO trả về khi đăng nhập)
    @Mapping(target = "accessToken", ignore = true)
    @Mapping(target = "tokenType", constant = "Bearer")
    LoginResponse toLoginResponse(UserEntity user);
}
