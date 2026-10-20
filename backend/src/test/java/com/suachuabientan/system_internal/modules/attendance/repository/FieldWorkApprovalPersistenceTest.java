package com.suachuabientan.system_internal.modules.attendance.repository;
import com.suachuabientan.system_internal.modules.attendance.entity.FieldWorkDay;
import org.hibernate.SessionFactory;
import org.hibernate.cfg.Configuration;
import org.junit.jupiter.api.*;
import org.springframework.data.jpa.repository.support.JpaRepositoryFactory;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.SharedEntityManagerCreator;
import org.springframework.transaction.support.TransactionTemplate;
import java.time.LocalDate;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;

class FieldWorkApprovalPersistenceTest {
    static SessionFactory factory;
    @BeforeAll static void database() {
        factory = new Configuration()
            .setProperty("hibernate.connection.url", "jdbc:h2:mem:field-approval;MODE=PostgreSQL;DB_CLOSE_DELAY=-1")
            .setProperty("hibernate.connection.driver_class", "org.h2.Driver")
            .setProperty("hibernate.hbm2ddl.auto", "create-drop")
            .addAnnotatedClass(FieldWorkDay.class).buildSessionFactory();
    }
    @AfterAll static void close() { if (factory != null) factory.close(); }
    @Test void onlyApprovedDaysReachAttendanceQueriesButOwnListIncludesAllStates() {
        var tx = new TransactionTemplate(new JpaTransactionManager(factory));
        var repo = new JpaRepositoryFactory(SharedEntityManagerCreator.createSharedEntityManager(factory))
            .getRepository(FieldWorkDayRepository.class);
        var employee = UUID.randomUUID(); var date = LocalDate.of(2026, 9, 21);
        tx.executeWithoutResult(t -> {
            for (int i = 0; i < 3; i++) {
                var day = new FieldWorkDay(); day.setEmployeeId(employee); day.setWorkDate(date.plusDays(i));
                day.setCreatedAt(java.time.Instant.now()); day.setUpdatedAt(java.time.Instant.now());
                day.setNote("ABC"); day.setStatus(new String[]{"PENDING", "APPROVED", "REJECTED"}[i]); repo.save(day);
            }
        });
        tx.executeWithoutResult(t -> {
            assertTrue(repo.findByEmployeeIdAndWorkDateAndIsDeletedFalse(employee, date).isPresent());
            assertEquals("PENDING", repo.findByEmployeeIdAndWorkDateAndIsDeletedFalse(employee, date).get().getStatus());
            assertEquals(1, repo.findByWorkDateAndIsDeletedFalse(date).size());
            assertEquals(1, repo.findByWorkDateAndIsDeletedFalse(date.plusDays(2)).size());
            assertEquals(3, repo.findByWorkDateBetweenAndIsDeletedFalse(date, date.plusDays(2)).size());
            assertEquals(3, repo.findByEmployeeIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateAsc(employee, date, date.plusDays(2)).size());
            assertEquals(3, repo.findByEmployeeIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateDesc(employee, date, date.plusDays(2)).size());
            var pending = repo.findTop100ByStatusAndIsDeletedFalseOrderByCreatedAtAsc("PENDING").getFirst();
            pending.setStatus("APPROVED"); repo.saveAndFlush(pending);
            assertEquals(3, repo.findByWorkDateBetweenAndIsDeletedFalse(date, date.plusDays(2)).size());
            assertTrue(repo.findTop100ByStatusAndIsDeletedFalseOrderByCreatedAtAsc("PENDING").isEmpty());
            pending.softDelete(employee); repo.saveAndFlush(pending);
            assertEquals(2, repo.findByWorkDateBetweenAndIsDeletedFalse(date, date.plusDays(2)).size());
        });
    }
}
