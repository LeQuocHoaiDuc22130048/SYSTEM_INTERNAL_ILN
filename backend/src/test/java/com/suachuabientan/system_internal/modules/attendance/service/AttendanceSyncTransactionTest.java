package com.suachuabientan.system_internal.modules.attendance.service;

import com.suachuabientan.system_internal.modules.attendance.dto.request.AttendanceSyncItemRequest;
import com.suachuabientan.system_internal.modules.attendance.dto.request.AttendanceSyncRequest;
import com.suachuabientan.system_internal.modules.attendance.entity.AttendanceRecord;
import com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType;
import com.suachuabientan.system_internal.modules.attendance.repository.AttendanceRecordRepository;
import com.suachuabientan.system_internal.modules.attendance.repository.WorkScheduleRepository;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import org.hibernate.Interceptor;
import org.hibernate.SessionFactory;
import org.hibernate.cfg.Configuration;
import org.hibernate.type.Type;
import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.data.jpa.repository.support.JpaRepositoryFactory;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.SharedEntityManagerCreator;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

class AttendanceSyncTransactionTest {
    private static SessionFactory sessionFactory;
    private TransactionTemplate transaction;
    private AttendanceRecordRepository records;
    private AttendanceService service;
    private UUID employeeId;

    @BeforeAll
    static void createDatabase() {
        sessionFactory = new Configuration()
                .setProperty("hibernate.connection.url", "jdbc:h2:mem:sync-" + UUID.randomUUID())
                .setProperty("hibernate.connection.driver_class", "org.h2.Driver")
                .setProperty("hibernate.hbm2ddl.auto", "create-drop")
                .addAnnotatedClass(AttendanceRecord.class)
                // Supply audit timestamps normally populated by Spring Data auditing.
                .setInterceptor(new Interceptor() {
                    @Override
                    public boolean onSave(Object entity, Object id, Object[] state, String[] names, Type[] types) {
                        for (int i = 0; i < names.length; i++) {
                            if (names[i].equals("createdAt") || names[i].equals("updatedAt")) {
                                state[i] = Instant.now();
                            }
                        }
                        return true;
                    }
                })
                .buildSessionFactory();
    }

    @AfterAll
    static void closeDatabase() {
        if (sessionFactory != null) sessionFactory.close();
    }

    @BeforeEach
    void setUp() {
        var manager = new JpaTransactionManager(sessionFactory);
        transaction = new TransactionTemplate(manager);
        var factory = new JpaRepositoryFactory(SharedEntityManagerCreator.createSharedEntityManager(sessionFactory));
        records = factory.getRepository(AttendanceRecordRepository.class);
        transaction.executeWithoutResult(status -> records.deleteAllInBatch());
        employeeId = UUID.randomUUID();
        var employee = new UserEntity();
        employee.setId(employeeId);
        employee.setFullName("Sync employee");
        employee.setFaceEnrolled(true);
        employee.setFaceEncoding("[1,0]");
        var users = mock(UserRepository.class);
        when(users.findById(employeeId)).thenReturn(Optional.of(employee));
        var faces = mock(FaceRecognitionService.class);
        when(faces.verify(anyString(), anyString(), anyString()))
                .thenReturn(new FaceRecognitionService.FaceVerificationResult(true, 0.98));
        var target = new AttendanceService(records, mock(WorkScheduleRepository.class), users, faces,
                mock(NotificationService.class), mock(FaceRecognitionMonitoringService.class), manager);
        var proxy = new ProxyFactory(target);
        proxy.setProxyTargetClass(true);
        proxy.addAdvice(new TransactionInterceptor(manager, new AnnotationTransactionAttributeSource()));
        service = (AttendanceService) proxy.getProxy();
    }

    @ParameterizedTest
    @ValueSource(ints = {0, 1, 2})
    void databaseFailureOnlyRejectsItsOwnLog(int failureIndex) {
        var first = item("good-first", 0, "tablet");
        var last = item("good-last", 3600, "tablet");
        // Exceed the real device_id column limit: failure occurs on database flush/commit.
        var bad = item("bad", 7200, "x".repeat(101));
        var logs = new ArrayList<>(List.of(first, last));
        logs.add(failureIndex, bad);

        var response = assertDoesNotThrow(() -> service.syncOfflineLogs(new AttendanceSyncRequest(logs), employeeId));

        assertEquals(3, response.total());
        assertEquals(2, response.synced());
        assertEquals(1, response.failed());
        assertEquals(0, response.skipped());
        assertEquals("FAILED", response.results().get(failureIndex).status());
        transaction.executeWithoutResult(status -> {
            assertEquals(2, records.count());
            assertTrue(records.findByDeviceLogIdAndIsDeletedFalse("good-first").isPresent());
            assertTrue(records.findByDeviceLogIdAndIsDeletedFalse("good-last").isPresent());
            assertTrue(records.findByDeviceLogIdAndIsDeletedFalse("bad").isEmpty());
        });

        var retry = service.syncOfflineLogs(new AttendanceSyncRequest(List.of(first, last)), employeeId);
        assertEquals(0, retry.synced());
        assertEquals(2, retry.skipped());
        assertEquals(0, retry.failed());
    }

    private AttendanceSyncItemRequest item(String logId, long seconds, String device) {
        return new AttendanceSyncItemRequest(logId, employeeId, AttendanceType.IN,
                Instant.parse("2026-09-18T01:00:00Z").plusSeconds(seconds), null, 0.98, null,
                "image", "image/png", device, null);
    }
}
