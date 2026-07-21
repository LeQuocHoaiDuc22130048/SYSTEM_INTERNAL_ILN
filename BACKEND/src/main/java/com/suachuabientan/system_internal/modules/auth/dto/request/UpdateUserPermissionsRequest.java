package com.suachuabientan.system_internal.modules.auth.dto.request;

import jakarta.validation.constraints.NotNull;
import java.util.Map;

/**
 * Request body để cập nhật permission overrides cho một user.
 * <p>
 * overrides: Map<permissionCode, granted>
 * - TRUE  → cấp thêm quyền (GRANT override)
 * - FALSE → thu hồi quyền  (DENY override)
 * - null  → xóa override, trả về kế thừa từ role
 * </p>
 * Gửi map rỗng {} để reset toàn bộ về mặc định role.
 */
public record UpdateUserPermissionsRequest(
        @NotNull
        Map<String, Boolean> overrides
) {
}
