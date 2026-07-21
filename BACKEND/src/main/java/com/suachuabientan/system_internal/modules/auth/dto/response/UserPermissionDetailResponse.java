package com.suachuabientan.system_internal.modules.auth.dto.response;

/**
 * Chi tiết 1 permission của user: nguồn gốc + trạng thái override.
 */
public record UserPermissionDetailResponse(
        String code,
        String name,
        String module,
        String description,

        /** TRUE nếu quyền này đến từ role mặc định */
        boolean fromRole,

        /**
         * Override của admin:
         *   - null  = không override (kế thừa từ role)
         *   - TRUE  = đã cấp thêm (GRANT)
         *   - FALSE = đã thu hồi (DENY)
         */
        Boolean overrideGranted,

        /** Quyền cuối cùng có hiệu lực */
        boolean effectiveGranted
) {
}
