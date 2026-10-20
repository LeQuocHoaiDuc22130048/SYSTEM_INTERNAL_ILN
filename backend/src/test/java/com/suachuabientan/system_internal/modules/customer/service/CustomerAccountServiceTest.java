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
import com.suachuabientan.system_internal.modules.customer.enums.CustomerType;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerAccountRepository;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CustomerAccountServiceTest {

    @Mock
    private CustomerRepository customerRepository;

    @Mock
    private CustomerAccountRepository customerAccountRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private RbacService rbacService;

    @InjectMocks
    private CustomerAccountService service;

    private UUID customerId;
    private Customer customer;

    @BeforeEach
    void setUp() {
        customerId = UUID.randomUUID();
        customer = new Customer();
        customer.setId(customerId);
        customer.setCustomerCode("KH-001");
        customer.setCustomerName("Công ty ABC");
        customer.setType(CustomerType.COMPANY);
        customer.setPhone("0987654321");
        customer.setEmail("abc@example.com");
        customer.setActive(true);
    }

    @Test
    void createAccount_success() {
        when(customerRepository.findByIdAndIsDeletedFalse(customerId)).thenReturn(Optional.of(customer));
        when(userRepository.existsByUsernameAndIsDeletedFalse("khach_abc")).thenReturn(false);
        when(passwordEncoder.encode("Secret123")).thenReturn("hashed_secret");

        UUID generatedUserId = UUID.randomUUID();
        when(userRepository.saveAndFlush(any(UserEntity.class))).thenAnswer(invocation -> {
            UserEntity u = invocation.getArgument(0);
            u.setId(generatedUserId);
            return u;
        });

        UUID generatedAccountId = UUID.randomUUID();
        when(customerAccountRepository.save(any(CustomerAccount.class))).thenAnswer(invocation -> {
            CustomerAccount a = invocation.getArgument(0);
            a.setId(generatedAccountId);
            return a;
        });

        CreateCustomerAccountRequest request = new CreateCustomerAccountRequest(
                "khach_abc", "Secret123", "Nguyễn Văn A", "0987654321", "a@abc.com", true
        );

        CustomerAccountCreatedResponse response = service.createAccount(customerId, request, UUID.randomUUID());

        assertNotNull(response);
        assertEquals("khach_abc", response.account().username());
        assertEquals("Secret123", response.plainPassword());
        assertTrue(response.shareableMessage().contains("khach_abc"));
        assertTrue(response.shareableMessage().contains("Secret123"));

        verify(rbacService).ensurePrimaryRoleAssigned(generatedUserId, UserRole.CUSTOMER);
    }

    @Test
    void createAccount_throws409_whenUsernameExists() {
        when(customerRepository.findByIdAndIsDeletedFalse(customerId)).thenReturn(Optional.of(customer));
        when(userRepository.existsByUsernameAndIsDeletedFalse("khach_abc")).thenReturn(true);

        CreateCustomerAccountRequest request = new CreateCustomerAccountRequest(
                "khach_abc", "Secret123", "Nguyễn Văn A", "0987654321", "a@abc.com", false
        );

        BusinessException ex = assertThrows(BusinessException.class, () ->
                service.createAccount(customerId, request, UUID.randomUUID())
        );
        assertEquals(409, ex.getStatusCode());
    }

    @Test
    void createAccount_throws400_whenCustomerInactive() {
        customer.setActive(false);
        when(customerRepository.findByIdAndIsDeletedFalse(customerId)).thenReturn(Optional.of(customer));

        CreateCustomerAccountRequest request = new CreateCustomerAccountRequest(
                "khach_abc", "Secret123", "Nguyễn Văn A", "0987654321", "a@abc.com", false
        );

        BusinessException ex = assertThrows(BusinessException.class, () ->
                service.createAccount(customerId, request, UUID.randomUUID())
        );
        assertEquals(400, ex.getStatusCode());
    }

    @Test
    void resetPassword_success() {
        UUID accountId = UUID.randomUUID();
        UUID userId = UUID.randomUUID();

        CustomerAccount account = CustomerAccount.builder()
                .userId(userId)
                .customerId(customerId)
                .contactName("Anh A")
                .active(true)
                .build();
        account.setId(accountId);

        UserEntity user = UserEntity.builder()
                .username("khach_a")
                .build();
        user.setId(userId);

        when(customerAccountRepository.findByIdAndIsDeletedFalse(accountId)).thenReturn(Optional.of(account));
        when(userRepository.findByIdAndIsDeletedFalse(userId)).thenReturn(Optional.of(user));
        when(passwordEncoder.encode("NewPass123")).thenReturn("hashed_new");

        ResetCustomerPasswordRequest request = new ResetCustomerPasswordRequest("NewPass123");
        CustomerAccountResponse response = service.resetPassword(customerId, accountId, request, UUID.randomUUID());

        assertNotNull(response);
        assertEquals("khach_a", response.username());
        verify(userRepository).save(user);
        assertEquals("hashed_new", user.getPasswordHash());
    }

    @Test
    void setStatus_success() {
        UUID accountId = UUID.randomUUID();
        UUID userId = UUID.randomUUID();

        CustomerAccount account = CustomerAccount.builder()
                .userId(userId)
                .customerId(customerId)
                .contactName("Anh A")
                .active(true)
                .build();
        account.setId(accountId);

        UserEntity user = UserEntity.builder()
                .username("khach_a")
                .status(UserStatus.ACTIVE)
                .build();
        user.setId(userId);

        when(customerAccountRepository.findByIdAndIsDeletedFalse(accountId)).thenReturn(Optional.of(account));
        when(userRepository.findByIdAndIsDeletedFalse(userId)).thenReturn(Optional.of(user));

        CustomerAccountResponse response = service.setStatus(customerId, accountId, false, UUID.randomUUID());

        assertFalse(response.active());
        assertFalse(account.isActive());
        assertEquals(UserStatus.SUSPENDED, user.getStatus());
    }
}
