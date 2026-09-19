package com.suachuabientan.system_internal.modules.auth.service;

import com.suachuabientan.system_internal.common.util.EmployeeCodeGenerator;
import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.modules.auth.dto.request.DeleteAccountRequest;
import com.suachuabientan.system_internal.modules.auth.entity.RefreshToken;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.enums.UserStatus;
import com.suachuabientan.system_internal.modules.auth.mapper.UserMapper;
import com.suachuabientan.system_internal.modules.auth.repository.*;
import com.suachuabientan.system_internal.modules.notification.repository.NotificationRepository;
import com.suachuabientan.system_internal.modules.notification.service.FcmService;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import org.hibernate.SessionFactory;
import org.hibernate.cfg.Configuration;
import org.hibernate.type.SqlTypes;
import org.hibernate.type.descriptor.jdbc.VarcharJdbcType;
import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.data.jpa.repository.support.JpaRepositoryFactory;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.SharedEntityManagerCreator;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import org.springframework.transaction.support.TransactionTemplate;

import java.sql.DriverManager;
import java.time.Instant;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AuthServiceDeletionTransactionTest {
    private static SessionFactory sessionFactory;
    private JpaTransactionManager transactionManager;
    private TransactionTemplate transaction;
    private UserRepository users;
    private RefreshTokenRepository tokens;
    private AuthService authService;
    private UserEntity user;
    private UUID reviewerId;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder(4);

    @BeforeAll
    static void createDatabase() throws Exception {
        String url = "jdbc:h2:mem:deletion-" + UUID.randomUUID() + ";DB_CLOSE_DELAY=-1";
        // Only adapt PostgreSQL named enum storage for H2. Keep the real entity/query/flush behavior.
        try (var connection = DriverManager.getConnection(url); var statement = connection.createStatement()) {
            statement.execute("CREATE DOMAIN user_role AS VARCHAR(32)");
            statement.execute("CREATE DOMAIN user_status AS VARCHAR(32)");
        }
        Configuration configuration = new Configuration()
                .setProperty("hibernate.connection.url", url)
                .setProperty("hibernate.connection.driver_class", "org.h2.Driver")
                .setProperty("hibernate.hbm2ddl.auto", "create-drop")
                .addAnnotatedClass(UserEntity.class)
                .addAnnotatedClass(RefreshToken.class);
        configuration.registerTypeContributor((types, registry) -> types.getTypeConfiguration()
                .getJdbcTypeRegistry().addDescriptor(SqlTypes.NAMED_ENUM, VarcharJdbcType.INSTANCE));
        sessionFactory = configuration.buildSessionFactory();
    }

    @AfterAll
    static void closeDatabase() {
        if (sessionFactory != null) sessionFactory.close();
    }

    @BeforeEach
    void setUp() {
        transactionManager = new JpaTransactionManager(sessionFactory);
        transaction = new TransactionTemplate(transactionManager);
        var factory = new JpaRepositoryFactory(SharedEntityManagerCreator.createSharedEntityManager(sessionFactory));
        users = factory.getRepository(UserRepository.class);
        tokens = factory.getRepository(RefreshTokenRepository.class);
        authService = serviceWith(tokens);
        reviewerId = UUID.randomUUID();
        user = new UserEntity();
        user.setUsername("delete-" + UUID.randomUUID());
        user.setPasswordHash(passwordEncoder.encode("correct-password"));
        user.setFullName("Deletion test");
        user.setRole(UserRole.EMPLOYEE);
        user.setStatus(UserStatus.ACTIVE);
        user.setDeviceToken("test-device-token");
        user.setFaceEncoding("[0.1,0.2]");
        user.setFaceEnrolled(true);
        user.setFaceVerifiedBy(reviewerId);
        user.setCreatedAt(Instant.now());
        user.setUpdatedAt(Instant.now());
        transaction.executeWithoutResult(status -> {
            users.save(user);
            tokens.save(newToken(user.getId()));
            tokens.save(newToken(user.getId()));
            tokens.save(newToken(reviewerId));
        });
    }

    private AuthService serviceWith(RefreshTokenRepository tokenRepository) {
        NotificationService notifications = new NotificationService(mock(NotificationRepository.class), users,
                mock(FcmService.class), mock(SimpMessagingTemplate.class));
        AuthService target = new AuthService(users, passwordEncoder, mock(UserMapper.class),
                mock(EmployeeCodeGenerator.class), mock(AuthenticationManager.class), mock(JwtUtil.class),
                tokenRepository, mock(UserRegistrationRequestRepository.class), notifications,
                mock(PasswordResetOtpRepository.class), mock(PasswordResetOtpService.class), mock(RbacService.class));
        ProxyFactory proxy = new ProxyFactory(target);
        proxy.setProxyTargetClass(true);
        proxy.addAdvice(new TransactionInterceptor(transactionManager, new AnnotationTransactionAttributeSource()));
        return (AuthService) proxy.getProxy();
    }

    @ParameterizedTest(name = "deletion commits and revokes sessions: selfDelete={0}")
    @ValueSource(booleans = {true, false})
    void deletionCommitsPrivacyCleanupAndRevokesOnlyTargetSessions(boolean selfDelete) {
        assertDoesNotThrow(() -> delete(authService, selfDelete));

        // Read in a new transaction: in-memory entity assertions would miss rollback.
        transaction.executeWithoutResult(status -> {
            UserEntity saved = users.findById(user.getId()).orElseThrow();
            assertTrue(saved.getIsDeleted());
            assertEquals(UserStatus.DELETED, saved.getStatus());
            assertNotNull(saved.getDeletedAt());
            assertEquals(selfDelete ? user.getId() : reviewerId, saved.getUpdatedBy());
            assertNull(saved.getDeviceToken());
            assertNull(saved.getFaceEncoding());
            assertFalse(saved.getFaceEnrolled());
            assertNull(saved.getFaceVerifiedBy());
            assertTrue(users.findByIdAndIsDeletedFalse(user.getId()).isEmpty());
            assertEquals(0L, tokens.countActiveSessionsByUserId(user.getId(), Instant.now()));
            assertEquals(1L, tokens.countActiveSessionsByUserId(reviewerId, Instant.now()));
        });
    }

    @ParameterizedTest(name = "revocation failure rolls deletion back: selfDelete={0}")
    @ValueSource(booleans = {true, false})
    void revocationFailurePreservesAccountAndSessions(boolean selfDelete) {
        // Inject a failure after the real bulk update, keeping DB writes and rollback real.
        RefreshTokenRepository failingTokens = mock(RefreshTokenRepository.class);
        doAnswer(invocation -> {
            tokens.revokeAllByUserId(invocation.getArgument(0));
            throw new IllegalStateException("Injected revocation failure");
        }).when(failingTokens).revokeAllByUserId(user.getId());

        assertThrows(IllegalStateException.class, () -> delete(serviceWith(failingTokens), selfDelete));
        transaction.executeWithoutResult(status -> {
            UserEntity saved = users.findByIdAndIsDeletedFalse(user.getId()).orElseThrow();
            assertEquals(UserStatus.ACTIVE, saved.getStatus());
            assertEquals("test-device-token", saved.getDeviceToken());
            assertEquals("[0.1,0.2]", saved.getFaceEncoding());
            assertTrue(saved.getFaceEnrolled());
            assertEquals(2L, tokens.countActiveSessionsByUserId(user.getId(), Instant.now()));
        });
    }

    private void delete(AuthService service, boolean selfDelete) {
        if (selfDelete) service.deleteMyAccount(user.getId(), new DeleteAccountRequest("correct-password", "test"));
        else service.deleteUser(user.getId(), reviewerId);
    }

    private RefreshToken newToken(UUID userId) {
        return RefreshToken.builder().userId(userId).tokenHash(UUID.randomUUID().toString())
                .createdAt(Instant.now()).expiresAt(Instant.now().plusSeconds(3600)).revoked(false).build();
    }
}
