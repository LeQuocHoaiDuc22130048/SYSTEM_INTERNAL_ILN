package com.suachuabientan.system_internal.modules.customer.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerRequest;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerResponse;
import com.suachuabientan.system_internal.modules.customer.entity.Customer;
import com.suachuabientan.system_internal.modules.customer.enums.CustomerType;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerRepository;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.ArrayList;
import java.util.Locale;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CustomerService {
    private final CustomerRepository repository;

    public Page<CustomerResponse> getAll(String keyword, Boolean active, CustomerType type, Pageable pageable) {
        // Fixed ordering prevents clients from sorting on unknown or internal properties.
        Pageable bounded = PageRequest.of(pageable.getPageNumber(), Math.min(pageable.getPageSize(), 50),
                Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("id")));
        String text = trimToNull(keyword);
        return repository.findAll((root, query, cb) -> {
            var predicates = new ArrayList<Predicate>();
            predicates.add(cb.isFalse(root.get("isDeleted")));
            if (active != null) predicates.add(cb.equal(root.get("active"), active));
            if (type != null) predicates.add(cb.equal(root.get("type"), type));
            if (text != null) {
                String pattern = "%" + text.toLowerCase(Locale.ROOT)
                        .replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%";
                predicates.add(cb.or(
                        cb.like(cb.lower(root.get("customerCode")), pattern, '\\'),
                        cb.like(cb.lower(root.get("customerName")), pattern, '\\'),
                        cb.like(cb.lower(root.get("phone")), pattern, '\\'),
                        cb.like(cb.lower(root.get("email")), pattern, '\\'),
                        cb.like(cb.lower(root.get("taxCode")), pattern, '\\')));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        }, bounded).map(this::toResponse);
    }

    public CustomerResponse getById(UUID id) { return toResponse(find(id)); }

    public CustomerResponse requireActive(UUID id) {
        Customer customer = find(id);
        if (!customer.isActive()) throw new BusinessException("Khách hàng đã ngừng hoạt động", 409);
        return toResponse(customer);
    }

    @Transactional
    public CustomerResponse create(CustomerRequest request) {
        Customer customer = new Customer();
        customer.setCustomerCode("KH-" + UUID.randomUUID().toString().replace("-", ""));
        apply(customer, request);
        return toResponse(repository.save(customer));
    }

    @Transactional
    public CustomerResponse update(UUID id, CustomerRequest request) {
        Customer customer = find(id);
        apply(customer, request);
        return toResponse(repository.save(customer));
    }

    @Transactional
    public CustomerResponse setActive(UUID id, boolean active) {
        Customer customer = find(id);
        customer.setActive(active);
        return toResponse(repository.save(customer));
    }

    private Customer find(UUID id) {
        return repository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy khách hàng: " + id));
    }

    private void apply(Customer customer, CustomerRequest request) {
        customer.setCustomerName(request.customerName().strip());
        customer.setType(request.type());
        customer.setPhone(trimToNull(request.phone()));
        customer.setEmail(trimToNull(request.email()));
        customer.setAddress(trimToNull(request.address()));
        customer.setTaxCode(trimToNull(request.taxCode()));
        customer.setNotes(trimToNull(request.notes()));
    }

    private String trimToNull(String value) { return value == null || value.isBlank() ? null : value.strip(); }

    private CustomerResponse toResponse(Customer customer) {
        return new CustomerResponse(customer.getId(), customer.getCustomerCode(), customer.getCustomerName(),
                customer.getType(), customer.getPhone(), customer.getEmail(), customer.getAddress(),
                customer.getTaxCode(), customer.getNotes(), customer.isActive(),
                customer.getCreatedAt(), customer.getUpdatedAt());
    }
}
