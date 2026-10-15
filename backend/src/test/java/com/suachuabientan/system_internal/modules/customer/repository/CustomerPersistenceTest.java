package com.suachuabientan.system_internal.modules.customer.repository;

import com.suachuabientan.system_internal.modules.customer.entity.Customer;
import com.suachuabientan.system_internal.modules.customer.enums.CustomerType;
import com.suachuabientan.system_internal.modules.customer.service.CustomerService;
import com.suachuabientan.system_internal.modules.repair.entity.RepairOrder;
import com.suachuabientan.system_internal.modules.repair.entity.RepairDevice;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import com.suachuabientan.system_internal.modules.repair.repository.RepairOrderRepository;
import org.hibernate.SessionFactory;
import org.hibernate.cfg.Configuration;
import org.junit.jupiter.api.*;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.jpa.repository.support.JpaRepositoryFactory;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.SharedEntityManagerCreator;
import org.springframework.transaction.support.TransactionTemplate;
import java.time.Instant;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;

class CustomerPersistenceTest {
    static SessionFactory factory;
    TransactionTemplate transaction;
    CustomerRepository customers;
    RepairOrderRepository orders;
    CustomerService service;

    @BeforeAll static void database() {
        factory = new Configuration()
                .setProperty("hibernate.connection.url", "jdbc:h2:mem:customers-" + UUID.randomUUID() + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1")
                .setProperty("hibernate.connection.driver_class", "org.h2.Driver")
                .setProperty("hibernate.hbm2ddl.auto", "create-drop")
                .addAnnotatedClass(Customer.class).addAnnotatedClass(RepairOrder.class)
                .addAnnotatedClass(RepairDevice.class).buildSessionFactory();
    }

    @AfterAll static void close() { if (factory != null) factory.close(); }

    @BeforeEach void setup() {
        transaction = new TransactionTemplate(new JpaTransactionManager(factory));
        var repositories = new JpaRepositoryFactory(SharedEntityManagerCreator.createSharedEntityManager(factory));
        customers = repositories.getRepository(CustomerRepository.class);
        orders = repositories.getRepository(RepairOrderRepository.class);
        service = new CustomerService(customers);
        transaction.executeWithoutResult(status -> { orders.deleteAll(); customers.deleteAll(); });
    }

    @Test void searchFindsContactsFiltersStatusAndEscapesWildcards() {
        transaction.executeWithoutResult(status -> {
            customers.save(customer("Công ty A", "KH-ONE", "0901234567", true));
            customers.save(customer("Khách 100%", "KH-TWO", "0909999999", false));
        });
        transaction.executeWithoutResult(status -> {
            assertEquals("KH-ONE", service.getAll("090123", true, null, PageRequest.of(0, 20)).getContent().get(0).customerCode());
            assertEquals(1, service.getAll("%", null, null, PageRequest.of(0, 20)).getTotalElements());
            assertEquals(0, service.getAll("_", null, null, PageRequest.of(0, 20)).getTotalElements());
            assertEquals(1, service.getAll("cÔNG TY", null, CustomerType.COMPANY, PageRequest.of(0, 20)).getTotalElements());
            assertEquals(0, service.getAll(null, null, CustomerType.INDIVIDUAL, PageRequest.of(0, 20)).getTotalElements());
        });
    }

    @Test void paginationIsBoundedAndDeletedProfilesAreHidden() {
        transaction.executeWithoutResult(status -> {
            for (int i = 0; i < 55; i++) customers.save(customer("Khách " + i, "KH-" + i, null, true));
            Customer deleted = customer("Đã xóa", "KH-DELETED", null, true);
            deleted.softDelete(UUID.randomUUID());
            customers.save(deleted);
        });
        transaction.executeWithoutResult(status -> {
            var first = service.getAll(null, null, null, PageRequest.of(0, 200));
            var second = service.getAll(null, null, null, PageRequest.of(1, 200));
            assertEquals(50, first.getNumberOfElements());
            assertEquals(55, first.getTotalElements());
            assertEquals(5, second.getNumberOfElements());
            assertTrue(first.getContent().stream().noneMatch(c -> c.customerCode().equals("KH-DELETED")));
        });
    }

    @Test void nativeOrderFilterCountsOnlyMatchingCustomerAndStaff() {
        UUID customerA = transaction.execute(status -> customers.save(customer("Trùng tên", "KH-A", null, true)).getId());
        UUID customerB = transaction.execute(status -> customers.save(customer("Trùng tên", "KH-B", null, true)).getId());
        UUID staffA = UUID.randomUUID();
        UUID staffB = UUID.randomUUID();
        transaction.executeWithoutResult(status -> {
            orders.save(order("RO-A1", customerA, staffA));
            orders.save(order("RO-A2", customerA, staffB));
            orders.save(order("RO-B1", customerB, staffA));
        });
        transaction.executeWithoutResult(status -> {
            var managerPage = orders.searchOrders(null, null, null, null, customerA.toString(), false, PageRequest.of(0, 1));
            assertEquals(2, managerPage.getTotalElements());
            assertEquals(customerA, managerPage.getContent().get(0).getCustomerId());
            var staffPage = orders.searchOrders(null, null, null, staffA.toString(), customerA.toString(), false, PageRequest.of(0, 20));
            assertEquals(1, staffPage.getTotalElements());
            assertEquals("RO-A1", staffPage.getContent().get(0).getOrderCode());
            assertEquals(3, orders.searchOrders(null, null, null, null, null, false, PageRequest.of(0, 20)).getTotalElements());
        });
    }

    @Test void unlinkedFilterAppliesBeforePaginationAndPreservesStaffScope() {
        UUID customerId = transaction.execute(status -> customers.save(customer("Linked", "KH-LINK", null, true)).getId());
        UUID staff = UUID.randomUUID();
        transaction.executeWithoutResult(status -> {
            orders.save(order("RO-LINKED", customerId, staff));
            orders.save(order("RO-FREE1", null, staff));
            orders.save(order("RO-FREE2", null, staff));
            orders.save(order("RO-OTHER", null, UUID.randomUUID()));
        });
        transaction.executeWithoutResult(status -> {
            var page = orders.searchOrders("RO-", null, null, staff.toString(), null, true, PageRequest.of(0, 1));
            assertEquals(2, page.getTotalElements());
            assertEquals(1, page.getNumberOfElements());
            assertNull(page.getContent().get(0).getCustomerId());
            assertEquals(staff, page.getContent().get(0).getReceivedBy());
            assertEquals(3, orders.searchOrders(null, null, null, null, null, true, PageRequest.of(0, 1)).getTotalElements());
        });
    }

    Customer customer(String name, String code, String phone, boolean active) {
        Customer customer = new Customer();
        customer.setCustomerName(name); customer.setCustomerCode(code); customer.setPhone(phone);
        customer.setType(CustomerType.COMPANY); customer.setActive(active);
        customer.setCreatedAt(Instant.now()); customer.setUpdatedAt(Instant.now());
        return customer;
    }

    RepairOrder order(String code, UUID customerId, UUID staff) {
        RepairOrder order = RepairOrder.builder().orderCode(code).customerId(customerId)
                .customerName("Trùng tên").deviceName("Biến tần").receivedBy(staff)
                .receivedAt(Instant.now()).status(RepairStatus.PENDING).priority(100).build();
        order.setCreatedAt(Instant.now()); order.setUpdatedAt(Instant.now());
        return order;
    }
}
