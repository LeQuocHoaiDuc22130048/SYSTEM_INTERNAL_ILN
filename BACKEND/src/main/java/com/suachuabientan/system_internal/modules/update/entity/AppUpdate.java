package com.suachuabientan.system_internal.modules.update.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "app_updates")
@Getter @Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AppUpdate extends BaseEntity {
    @Column(nullable = false, length = 50)
    private String version;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String changelog;

    @Column(name = "download_url", nullable = false, length = 500)
    private String downloadUrl;

    @Column(nullable = false)
    @Builder.Default
    private Boolean mandatory = false;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT"; // DRAFT, RELEASED

    @Column(name = "released_at")
    private Instant releasedAt;
}
