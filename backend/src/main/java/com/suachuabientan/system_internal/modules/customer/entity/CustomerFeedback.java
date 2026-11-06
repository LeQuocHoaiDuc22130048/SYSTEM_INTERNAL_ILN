package com.suachuabientan.system_internal.modules.customer.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "customer_feedbacks")
@Getter
@Setter
public class CustomerFeedback extends BaseEntity {

    @Column(name = "order_code", length = 100)
    private String orderCode;

    @Column(name = "customer_id")
    private UUID customerId;

    @Column(name = "customer_name", nullable = false)
    private String customerName;

    @Column(name = "customer_phone", length = 50)
    private String customerPhone;

    @Column(name = "customer_code", length = 50)
    private String customerCode;

    @Column(name = "device_model")
    private String deviceModel;

    @Column(nullable = false)
    private int rating = 5;

    @Column(nullable = false, length = 50)
    private String type = "SERVICE_QUALITY";

    @Column(name = "type_name", nullable = false, length = 100)
    private String typeName = "Đánh giá chất lượng";

    @Column(columnDefinition = "TEXT")
    private String tags;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(columnDefinition = "TEXT")
    private String images;

    @Column(nullable = false, length = 50)
    private String status = "PENDING";

    @Column(name = "status_name", nullable = false, length = 100)
    private String statusName = "Chờ tiếp nhận";

    @Column(columnDefinition = "TEXT")
    private String reply;

    @Column(name = "reply_at")
    private Instant replyAt;

    @Column(name = "replied_by")
    private String repliedBy;

    @Column(name = "is_urgent", nullable = false)
    private boolean isUrgent = false;
}

