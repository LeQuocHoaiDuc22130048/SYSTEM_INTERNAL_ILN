package com.suachuabientan.system_internal.modules.customer.entity;

import com.suachuabientan.system_internal.common.model.BaseEntity;
import com.suachuabientan.system_internal.modules.customer.enums.CustomerType;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "customers")
@Getter
@Setter
public class Customer extends BaseEntity {
    @Column(name = "customer_code", nullable = false, unique = true, length = 35)
    private String customerCode;
    @Column(name = "customer_name", nullable = false, length = 100)
    private String customerName;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private CustomerType type;
    @Column(length = 20)
    private String phone;
    @Column(length = 254)
    private String email;
    @Column(length = 500)
    private String address;
    @Column(name = "tax_code", length = 30)
    private String taxCode;
    @Column(length = 2000)
    private String notes;
    @Column(nullable = false)
    private boolean active = true;
}
