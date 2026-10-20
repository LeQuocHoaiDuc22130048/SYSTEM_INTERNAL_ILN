package com.suachuabientan.system_internal.modules.customer.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerRequest;
import com.suachuabientan.system_internal.modules.customer.entity.Customer;
import com.suachuabientan.system_internal.modules.customer.enums.CustomerType;
import com.suachuabientan.system_internal.modules.customer.repository.CustomerRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import java.util.Optional;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CustomerServiceTest {
    @Mock CustomerRepository repository;
    CustomerService service;

    @BeforeEach void setup() { service = new CustomerService(repository); }

    @Test void createTrimsContactsAndGeneratesIndependentCodesForSameName() {
        when(repository.save(any(Customer.class))).thenAnswer(invocation -> {
            Customer customer = invocation.getArgument(0);
            customer.setId(UUID.randomUUID());
            return customer;
        });
        var request = new CustomerRequest("  Công ty A  ", CustomerType.COMPANY,
                " 0901234567 ", " sales@example.com ", "  Hà Nội  ", " 123456 ", "  ");
        var first = service.create(request);
        var second = service.create(request);
        assertEquals("Công ty A", first.customerName());
        assertEquals("0901234567", first.phone());
        assertEquals("sales@example.com", first.email());
        assertNull(first.notes());
        assertTrue(first.active());
        assertNotEquals(first.customerCode(), second.customerCode());
    }

    @Test void normalizeCustomerNameFixesImeCapitalizationGlitches() {
        assertEquals("Anh Dũng", CustomerService.normalizeCustomerName("anh dŨNG", CustomerType.INDIVIDUAL));
        assertEquals("Nguyên Lương Tuân", CustomerService.normalizeCustomerName("NguyÊn LƯƠNG TuÂn", CustomerType.INDIVIDUAL));
        assertEquals("Nguyen Van A", CustomerService.normalizeCustomerName("nguyen van a", CustomerType.INDIVIDUAL));
        assertEquals("Công ty TNHH MTV Giải Pháp ABB", CustomerService.normalizeCustomerName("công ty tnhh mtv giải pháp abb", CustomerType.COMPANY));
    }

    @Test void inactiveCustomerRemainsReadableButCannotBeAssigned() {
        Customer customer = customer();
        customer.setActive(false);
        when(repository.findByIdAndIsDeletedFalse(customer.getId())).thenReturn(Optional.of(customer));
        assertFalse(service.getById(customer.getId()).active());
        BusinessException error = assertThrows(BusinessException.class,
                () -> service.requireActive(customer.getId()));
        assertEquals(409, error.getStatusCode());
    }

    @Test void missingOrDeletedCustomerCannotBeAssigned() {
        UUID id = UUID.randomUUID();
        when(repository.findByIdAndIsDeletedFalse(id)).thenReturn(Optional.empty());
        assertThrows(ResourceNotFoundException.class, () -> service.requireActive(id));
    }

    @Test void updatePreservesIdentityAndStatus() {
        Customer customer = customer();
        customer.setActive(false);
        when(repository.findByIdAndIsDeletedFalse(customer.getId())).thenReturn(Optional.of(customer));
        when(repository.save(customer)).thenReturn(customer);
        var response = service.update(customer.getId(), new CustomerRequest(
                "Tên mới", CustomerType.INDIVIDUAL, null, null, null, null, null));
        assertEquals("KH-EXISTING", response.customerCode());
        assertEquals(customer.getId(), response.id());
        assertEquals("Tên Mới", response.customerName());
        assertFalse(response.active());
    }

    @Test void statusCanBeDisabledAndEnabledWithoutDeletingHistory() {
        Customer customer = customer();
        when(repository.findByIdAndIsDeletedFalse(customer.getId())).thenReturn(Optional.of(customer));
        when(repository.save(customer)).thenReturn(customer);
        assertFalse(service.setActive(customer.getId(), false).active());
        assertTrue(service.setActive(customer.getId(), true).active());
        assertFalse(customer.getIsDeleted());
    }

    private Customer customer() {
        Customer customer = new Customer();
        customer.setId(UUID.randomUUID());
        customer.setCustomerCode("KH-EXISTING");
        customer.setCustomerName("Khách A");
        customer.setType(CustomerType.INDIVIDUAL);
        customer.setActive(true);
        return customer;
    }
}
