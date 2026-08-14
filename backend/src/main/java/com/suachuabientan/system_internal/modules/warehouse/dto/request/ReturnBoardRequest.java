package com.suachuabientan.system_internal.modules.warehouse.dto.request;

import java.util.UUID;

/**
 * Yêu cầu trả bo mạch về kho.
 *
 * @param checkoutId     ID lượt mượn cụ thể (nếu có)
 * @param returnType     FULL = trả hết, PARTIAL = trả một phần
 * @param returnQuantity Số lượng thực tế trả về (chỉ dùng khi returnType = PARTIAL)
 * @param reason         Lý do bị thiếu / ghi chú (bắt buộc khi trả hết mà số lượng thực < lấy ra)
 * @param notes          Ghi chú tổng quan sau khi sửa chữa
 */
public record ReturnBoardRequest(
        UUID checkoutId,
        String returnType,
        Integer returnQuantity,
        String reason,
        String notes
) {
}
