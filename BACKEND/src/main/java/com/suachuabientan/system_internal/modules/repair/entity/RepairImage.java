package com.suachuabientan.system_internal.modules.repair.entity;


import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

import java.time.Instant;
import java.util.UUID;
import com.suachuabientan.system_internal.modules.repair.enums.RepairMediaType;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;

@Entity
@Table(name = "repair_images")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RepairImage extends BaseEntity {
    @Column(name = "order_id", nullable = false)
    private UUID orderId;

    @Column(name = "image_url", nullable = false, length = 500)
    private String imageUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "media_type", nullable = false, length = 20)
    @Builder.Default
    private RepairMediaType mediaType = RepairMediaType.IMAGE;

    /** VD: "Ảnh trước sửa", "Ảnh sau sửa", "Ảnh lỗi" */
    @Column(length = 255)
    private String caption;

    @Column(name = "uploaded_by", nullable = false)
    private UUID uploadedBy;

    @Column(name = "uploaded_at", nullable = false)
    private Instant uploadedAt;
}
