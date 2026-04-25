package com.suachuabientan.system_internal.modules.auth.domain;

import com.suachuabientan.system_internal.common.enums.Roles;
import com.suachuabientan.system_internal.common.model.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import lombok.experimental.FieldDefaults;

@Entity
@Table(name = "users")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@FieldDefaults(level = lombok.AccessLevel.PRIVATE)
public class UserEntity extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    Long id;

    @Column(unique = true, nullable = false)
    String username;

    @Column(nullable = false)
    String password;

    String fullName;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    Roles role;

    boolean isActive = true;
}
