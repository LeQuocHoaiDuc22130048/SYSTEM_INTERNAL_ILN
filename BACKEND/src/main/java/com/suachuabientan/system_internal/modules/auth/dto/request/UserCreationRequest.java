package com.suachuabientan.system_internal.modules.auth.dto.request;

import com.suachuabientan.system_internal.common.enums.Roles;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.*;
import lombok.experimental.FieldDefaults;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@FieldDefaults(level = AccessLevel.PRIVATE)
public class UserCreationRequest {
    @NotBlank(message = "Username không được để trống")
    @Size(min = 4, message = "Username phải có ít nhất 4 ký tự")
    String username;

    @NotBlank(message = "Mật khẩu không được để trống")
    @Size(min = 12, message = "Mật khẩu phải có ít nhất 12 ký tự")
    String password;

    @NotBlank(message = "Họ tên không được để trống")
    String fullName;

    @NotBlank(message = "Vai trò không được để trống")
    Roles role;
}
