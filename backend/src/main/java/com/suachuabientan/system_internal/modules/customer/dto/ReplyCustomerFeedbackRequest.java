package com.suachuabientan.system_internal.modules.customer.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class ReplyCustomerFeedbackRequest {
    private String status = "IN_PROGRESS"; // IN_PROGRESS, RESOLVED

    @NotBlank(message = "Nội dung phản hồi kỹ thuật không được để trống")
    private String reply;

    private String repliedBy;
}

