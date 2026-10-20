package com.suachuabientan.system_internal.modules.customer.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "portal_support_configs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PortalSupportConfig {

    @Id
    @Column(name = "id", nullable = false)
    private UUID id;

    @Column(name = "hotline_number", nullable = false, length = 50)
    private String hotlineNumber;

    @Column(name = "hotline_label", nullable = false, length = 100)
    private String hotlineLabel;

    @Column(name = "zalo_url", nullable = false, length = 255)
    private String zaloUrl;

    @Column(name = "zalo_label", nullable = false, length = 100)
    private String zaloLabel;

    @Column(name = "working_hours", nullable = false, length = 200)
    private String workingHours;

    @Column(name = "workshop_address", nullable = false, length = 500)
    private String workshopAddress;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @Column(name = "updated_by")
    private UUID updatedBy;
}
