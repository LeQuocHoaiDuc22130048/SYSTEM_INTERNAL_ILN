package com.suachuabientan.system_internal.modules.customer.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Data
@Builder
public class CustomerFeedbackResponse {
    private UUID id;
    private String orderCode;
    private UUID customerId;
    private String customerName;
    private String customerPhone;
    private String customerCode;
    private String deviceModel;
    private int rating;
    private String type;
    private String typeName;
    private List<String> tags;
    private String content;
    private List<String> images;
    private String status;
    private String statusName;
    private String reply;
    private Instant replyAt;
    private String repliedBy;
    private boolean isUrgent;
    private Instant createdAt;
    private Instant updatedAt;
}

