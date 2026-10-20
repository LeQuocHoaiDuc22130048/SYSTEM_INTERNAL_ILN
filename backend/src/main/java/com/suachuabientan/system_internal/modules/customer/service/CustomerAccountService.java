package com.suachuabientan.system_internal.modules.customer.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.auth.service.RbacService;
import com.suachuabientan.system_internal.modules.customer.dto.CreateCustomerAccountRequest;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerAccountCreatedResponse;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerAccountResponse;
import com.suachuabientan.system_internal.modules.customer.dto.ResetCustomerPasswordRequest;
import com.suachuabientan.system_internal.modules.customer.entity.Customer;
import com.suachuabientan.system_internal.modules.customer.entity.CustomerAccount;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerAccountRepository;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class CustomerAccountService {

    private final CustomerRepository customerRepository;
    private final CustomerAccountRepository customerAccountRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final RbacService rbacService;

    @Transactional
    public CustomerAccountCreatedResponse createAccount(UUID customerId, CreateCustomerAccountRequest request, UUID actorUserId) {
        Customer customer = customerRepository.findByIdAndIsDeletedFalse(customerId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy khách hàng: " + customerId));

        if (!customer.isActive()) {
            throw new BusinessException("Hồ sơ khách hàng đã ngừng hoạt động, không thể tạo tài khoản", 400);
        }

        String username = request.username().strip();
        if (userRepository.existsByUsernameAndIsDeletedFalse(username)) {
            throw new BusinessException("Tên đăng nhập '" + username + "' đã tồn tại trong hệ thống", 409);
        }

        String phone = request.phone() != null && !request.phone().isBlank()
                ? request.phone().strip()
                : customer.getPhone();

        String email = request.email() != null && !request.email().isBlank()
                ? request.email().strip()
                : customer.getEmail();

        UserEntity user = UserEntity.builder()
                .username(username)
                .passwordHash(passwordEncoder.encode(request.password()))
                .fullName(request.contactName().strip())
                .phone(phone)
                .role(UserRole.CUSTOMER)
                .status(UserStatus.ACTIVE)
                .faceEnrolled(false)
                .build();

        UserEntity savedUser = userRepository.saveAndFlush(user);
        rbacService.ensurePrimaryRoleAssigned(savedUser.getId(), UserRole.CUSTOMER);

        CustomerAccount account = CustomerAccount.builder()
                .userId(savedUser.getId())
                .customerId(customerId)
                .contactName(request.contactName().strip())
                .phone(phone)
                .email(email)
                .isPrimary(true)
                .mustChangePassword(Boolean.TRUE.equals(request.mustChangePassword()))
                .active(true)
                .build();

        CustomerAccount savedAccount = customerAccountRepository.save(account);

        String message = """
                Kính gửi Quý khách hàng %s,
                Hệ thống Sửa Chữa Biến Tần xin gửi thông tin tài khoản theo dõi tiến độ sửa chữa thiết bị:
                - Trang tra cứu / Portal: /portal
                - Tên đăng nhập: %s
                - Mật khẩu: %s
                Quý khách có thể đăng nhập để kiểm tra tiến độ và lịch sử sửa chữa bất kỳ lúc nào.
                """.formatted(customer.getCustomerName(), username, request.password());

        log.info("Tạo tài khoản khách hàng thành công: customerId={}, userId={}, username={}, by={}",
                customerId, savedUser.getId(), username, actorUserId);

        return new CustomerAccountCreatedResponse(
                toResponse(savedAccount, username),
                request.password(),
                message.strip()
        );
    }

    @Transactional(readOnly = true)
    public List<CustomerAccountResponse> getAccounts(UUID customerId) {
        List<CustomerAccount> accounts = customerAccountRepository.findByCustomerIdAndIsDeletedFalseOrderByCreatedAtDesc(customerId);
        if (accounts.isEmpty()) {
            return List.of();
        }

        List<UUID> userIds = accounts.stream().map(CustomerAccount::getUserId).toList();
        Map<UUID, UserEntity> userMap = userRepository.findAllById(userIds).stream()
                .collect(Collectors.toMap(UserEntity::getId, Function.identity()));

        return accounts.stream()
                .map(acc -> {
                    UserEntity user = userMap.get(acc.getUserId());
                    String username = user != null ? user.getUsername() : "";
                    return toResponse(acc, username);
                })
                .toList();
    }

    @Transactional
    public CustomerAccountResponse resetPassword(UUID customerId, UUID accountId, ResetCustomerPasswordRequest request, UUID actorUserId) {
        CustomerAccount account = findAccount(customerId, accountId);
        UserEntity user = userRepository.findByIdAndIsDeletedFalse(account.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng của tài khoản: " + account.getUserId()));

        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
        userRepository.save(user);

        log.info("Reset mật khẩu tài khoản khách hàng: customerId={}, accountId={}, by={}", customerId, accountId, actorUserId);
        return toResponse(account, user.getUsername());
    }

    @Transactional
    public CustomerAccountResponse setStatus(UUID customerId, UUID accountId, boolean active, UUID actorUserId) {
        CustomerAccount account = findAccount(customerId, accountId);
        account.setActive(active);
        customerAccountRepository.save(account);

        UserEntity user = userRepository.findByIdAndIsDeletedFalse(account.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng của tài khoản: " + account.getUserId()));

        user.setStatus(active ? UserStatus.ACTIVE : UserStatus.SUSPENDED);
        userRepository.save(user);

        log.info("Cập nhật trạng thái tài khoản khách hàng: customerId={}, accountId={}, active={}, by={}",
                customerId, accountId, active, actorUserId);
        return toResponse(account, user.getUsername());
    }

    private CustomerAccount findAccount(UUID customerId, UUID accountId) {
        CustomerAccount account = customerAccountRepository.findByIdAndIsDeletedFalse(accountId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản: " + accountId));
        if (!account.getCustomerId().equals(customerId)) {
            throw new BusinessException("Tài khoản không thuộc hồ sơ khách hàng này", 400);
        }
        return account;
    }

    private CustomerAccountResponse toResponse(CustomerAccount account, String username) {
        return new CustomerAccountResponse(
                account.getId(),
                account.getUserId(),
                account.getCustomerId(),
                username,
                account.getContactName(),
                account.getPhone(),
                account.getEmail(),
                account.isActive(),
                account.isMustChangePassword(),
                account.getCreatedAt()
        );
    }
}
