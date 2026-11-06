package com.suachuabientan.system_internal.modules.customer.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.util.List;

@Data
public class CreateCustomerFeedbackRequest {
    private String orderCode;
    private String deviceModel;

    @Min(value = 1, message = "Số sao tối thiểu là 1")
    @Max(value = 5, message = "Số sao tối đa là 5")
    private int rating = 5;

    private String type = "SERVICE_QUALITY"; // SERVICE_QUALITY, WARRANTY_ISSUE, SUGGESTION
    private String typeName;
    private List<String> tags;

    @NotBlank(message = "Nội dung phản hồi không được để trống")
    private String content;

    private List<String> images;
    private boolean isUrgent = false;
}

