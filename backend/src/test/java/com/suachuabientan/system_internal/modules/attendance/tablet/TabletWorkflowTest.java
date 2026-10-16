package com.suachuabientan.system_internal.modules.attendance.tablet;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.suachuabientan.system_internal.modules.attendance.service.AttendanceService;
import com.suachuabientan.system_internal.modules.attendance.dto.request.*;
import com.suachuabientan.system_internal.modules.attendance.dto.response.*;
import com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.*;
import org.hibernate.SessionFactory;
import org.hibernate.cfg.Configuration;
import org.springframework.data.jpa.repository.support.JpaRepositoryFactory;
import org.springframework.orm.jpa.*;
import org.springframework.transaction.support.TransactionTemplate;
import org.junit.jupiter.api.*;
import java.util.*;
import java.time.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class TabletWorkflowTest {
    static SessionFactory db;
    TransactionTemplate tx;
    TabletDeviceRepository devices;
    TabletSubmissionRepository submissions;
    TabletDeviceService registry;
    TabletSyncService sync;
    UUID account=UUID.randomUUID();
    UUID actor=UUID.randomUUID();
    TabletLeaseSigner signer;
    AttendanceService attendance;
    @BeforeAll static void open() {
        db=new Configuration().setProperty("hibernate.connection.url","jdbc:h2:mem:tablet;DB_CLOSE_DELAY=-1").setProperty("hibernate.connection.driver_class","org.h2.Driver").setProperty("hibernate.hbm2ddl.auto","create-drop").addAnnotatedClass(TabletDevice.class).addAnnotatedClass(TabletLease.class).addAnnotatedClass(TabletEvent.class).addAnnotatedClass(TabletSubmission.class).addAnnotatedClass(com.suachuabientan.system_internal.modules.attendance.entity.AttendanceRecord.class).setInterceptor(new org.hibernate.Interceptor() {
            @Override public boolean onSave(Object entity,Object id,Object[] state,String[] names,org.hibernate.type.Type[] types) {
                for(int i=0;i<names.length;i++)if(names[i].equals("createdAt")||names[i].equals("updatedAt"))state[i]=Instant.now();
                return true;
            }
        }).buildSessionFactory();
    }
    @AfterAll static void close() {
        db.close();
    }
    @BeforeEach void setup() {
        var manager=new JpaTransactionManager(db);
        tx=new TransactionTemplate(manager);
        var factory=new JpaRepositoryFactory(SharedEntityManagerCreator.createSharedEntityManager(db));
        devices=factory.getRepository(TabletDeviceRepository.class);
        submissions=factory.getRepository(TabletSubmissionRepository.class);
        var leases=factory.getRepository(TabletLeaseRepository.class);
        var events=factory.getRepository(TabletEventRepository.class);
        var user=new UserEntity();
        user.setId(account);
        user.setUsername("attendance");
        user.setRole(UserRole.ATTENDANCE);
        user.setStatus(UserStatus.ACTIVE);
        user.setIsDeleted(false);
        var users=mock(UserRepository.class);
        when(users.findById(account)).thenReturn(Optional.of(user));
        when(users.findForFieldWorkUpdate(account)).thenReturn(Optional.of(user));
        signer=new TabletLeaseSigner("test-signing-key-with-at-least-32-bytes",Clock.fixed(Instant.parse("2026-10-16T00:00:00Z"),ZoneOffset.UTC));
        registry=new TabletDeviceService(devices,leases,events,users,signer,SharedEntityManagerCreator.createSharedEntityManager(db));
        attendance=mock(AttendanceService.class);
        sync=new TabletSyncService(registry,devices,submissions,attendance,new ObjectMapper().registerModule(new JavaTimeModule()),manager,signer,SharedEntityManagerCreator.createSharedEntityManager(db));
    }
    TabletContracts.Device register() {
        return tx.execute(s->registry.register(account,new TabletContracts.Register(UUID.randomUUID(),"s".repeat(43),"Tablet", "Android","14","1")));
    }
    @Test void pendingCannotObtainLeaseAndOnlyOneDeviceIsApproved() {
        var a=register();
        var b=register();
        assertNull(tx.execute(s->registry.heartbeat(account,a.id(),"s".repeat(43),new TabletContracts.Beat(0,"1"))).lease());
        tx.execute(s->registry.action(a.id(),actor,"approve","approved"));
        tx.execute(s->registry.action(b.id(),actor,"approve","replacement"));
        assertEquals("BLOCKED",devices.findById(a.id()).orElseThrow().getStatus());
        assertEquals("APPROVED",devices.findById(b.id()).orElseThrow().getStatus());
        assertThrows(RuntimeException.class,()->registry.authenticate(account,b.id(),"wrong"));
    }
    @Test void blockedUploadIsDurableAndReplayKeepsReviewIdEvenAfterUnblock() {
        var a=register();
        tx.execute(s->registry.action(a.id(),actor,"approve","approved"));
        var beat=tx.execute(s->registry.heartbeat(account,a.id(),"s".repeat(43),new TabletContracts.Beat(1,"1")));
        tx.execute(s->registry.action(a.id(),actor,"block","lost"));
        var item=new AttendanceSyncItemRequest("local-1",UUID.randomUUID(),AttendanceType.IN,signer.now(),signer.now(),.9,null,"photo","image/jpeg",a.id().toString(),null,beat.lease().id(),beat.lease().signature());
        var request=new AttendanceSyncRequest(List.of(item));
        var first=sync.sync(account,a.id(),"s".repeat(43),request);
        assertEquals("PENDING_REVIEW",first.results().getFirst().status());
        assertNotNull(first.results().getFirst().reviewId());
        tx.execute(s->registry.action(a.id(),actor,"unblock","found"));
        var retry=sync.sync(account,a.id(),"s".repeat(43),request);
        assertEquals(first.results().getFirst().reviewId(),retry.results().getFirst().reviewId());
        verifyNoInteractions(attendance);
        var changed=new AttendanceSyncItemRequest("local-1",item.employeeId(),AttendanceType.OUT,signer.now(),signer.now(),.9,null,"photo","image/jpeg",a.id().toString(),null,beat.lease().id(),beat.lease().signature());
        assertEquals("REJECTED",sync.sync(account,a.id(),"s".repeat(43),new AttendanceSyncRequest(List.of(changed))).results().getFirst().status());
    }
    @Test void permanentFaceRejectionCreatesDurableReceiptInsteadOfRetryingForever() {
        var a=register();
        tx.execute(s->registry.action(a.id(),actor,"approve","approved"));
        var beat=tx.execute(s->registry.heartbeat(account,a.id(),"s".repeat(43),new TabletContracts.Beat(1,"1")));
        var item=new AttendanceSyncItemRequest("face-rejected",UUID.randomUUID(),AttendanceType.IN,signer.now(),signer.now(),.9,null,"photo","image/jpeg",a.id().toString(),null,beat.lease().id(),beat.lease().signature());
        when(attendance.syncTabletLog(any(),any())).thenThrow(new com.suachuabientan.system_internal.common.exception.BusinessException("Face mismatch",403));
        var first=sync.sync(account,a.id(),"s".repeat(43),new AttendanceSyncRequest(List.of(item))).results().getFirst();
        assertEquals("REJECTED",first.status());
        assertNotNull(first.reviewId());
        var again=sync.sync(account,a.id(),"s".repeat(43),new AttendanceSyncRequest(List.of(item))).results().getFirst();
        assertEquals(first.reviewId(),again.reviewId());
        verify(attendance,times(1)).syncTabletLog(any(),any());
    }
    @Test void approvedHistoricalUploadCreatesExactlyOneRecordAndReviewsUseSameTransaction() {
        var manager=new JpaTransactionManager(db);
        var factory=new JpaRepositoryFactory(SharedEntityManagerCreator.createSharedEntityManager(db));
        var records=factory.getRepository(com.suachuabientan.system_internal.modules.attendance.repository.AttendanceRecordRepository.class);
        UUID employee=UUID.randomUUID();
        var u=new UserEntity();
        u.setId(employee);
        u.setFullName("Employee");
        u.setFaceEnrolled(true);
        u.setFaceEncoding("[1,0]");
        u.setStatus(UserStatus.ACTIVE);
        u.setIsDeleted(false);
        var users=mock(UserRepository.class);
        when(users.findById(employee)).thenReturn(Optional.of(u));
        var faces=mock(com.suachuabientan.system_internal.modules.attendance.service.FaceRecognitionService.class);
        when(faces.verify(anyString(),anyString(),anyString())).thenReturn(new com.suachuabientan.system_internal.modules.attendance.service.FaceRecognitionService.FaceVerificationResult(true,.98));
        var target=new AttendanceService(records,mock(com.suachuabientan.system_internal.modules.attendance.repository.WorkScheduleRepository.class),users,faces,mock(com.suachuabientan.system_internal.modules.notification.service.NotificationService.class),mock(com.suachuabientan.system_internal.modules.attendance.service.FaceRecognitionMonitoringService.class),manager,mock(com.suachuabientan.system_internal.modules.attendance.repository.FieldWorkDayRepository.class));
        var proxy=new org.springframework.aop.framework.ProxyFactory(target);
        proxy.setProxyTargetClass(true);
        proxy.addAdvice(new org.springframework.transaction.interceptor.TransactionInterceptor(manager,new org.springframework.transaction.annotation.AnnotationTransactionAttributeSource()));
        var service=new TabletSyncService(registry,devices,submissions,(AttendanceService)proxy.getProxy(),new ObjectMapper().registerModule(new JavaTimeModule()),manager,signer,SharedEntityManagerCreator.createSharedEntityManager(db));
        var a=register();
        tx.execute(s->registry.action(a.id(),actor,"approve","approved"));
        var lease=tx.execute(s->registry.heartbeat(account,a.id(),"s".repeat(43),new TabletContracts.Beat(1,"1"))).lease();
        var item=new AttendanceSyncItemRequest("valid-record",employee,AttendanceType.IN,signer.now(),signer.now(),.9,null,"photo","image/jpeg",a.id().toString(),null,lease.id(),lease.signature());
        var first=service.sync(account,a.id(),"s".repeat(43),new AttendanceSyncRequest(List.of(item))).results().getFirst();
        assertEquals("SYNCED",first.status());
        var retry=service.sync(account,a.id(),"s".repeat(43),new AttendanceSyncRequest(List.of(item))).results().getFirst();
        assertEquals(first.serverRecordId(),retry.serverRecordId());
        tx.executeWithoutResult(s-> {
            assertEquals(signer.now(),records.findById(first.serverRecordId()).orElseThrow().getCheckTime());
        });
        tx.execute(s->registry.action(a.id(),actor,"block","lost"));
        var out=new AttendanceSyncItemRequest("pending-record",employee,AttendanceType.OUT,signer.now(),signer.now(),.9,null,"photo","image/jpeg",a.id().toString(),null,lease.id(),lease.signature());
        var pending=service.sync(account,a.id(),"s".repeat(43),new AttendanceSyncRequest(List.of(out))).results().getFirst();
        assertEquals("PENDING_REVIEW",pending.status());
        var approved=service.review(pending.reviewId(),actor,true,"checked evidence");
        assertEquals("SYNCED",approved.getStatus());
        assertEquals(approved.getRecordId(),service.review(pending.reviewId(),actor,true,"retry").getRecordId());
        assertEquals(2,records.findByEmployeeIdAndCheckTimeBetween(employee,signer.now().minusSeconds(1),signer.now().plusSeconds(1)).size());
        assertEquals(approved.getRecordId(),service.own(account,a.id(),"s".repeat(43),List.of(pending.reviewId())).getFirst().getRecordId());
    }
    @Test void stalePersistenceContextCannotRestoreARevokedLeaseVersion() throws Exception {
        var tablet=register();tx.execute(t->registry.action(tablet.id(),actor,"approve","approved"));
        var loaded=new java.util.concurrent.CountDownLatch(1);var blocked=new java.util.concurrent.CountDownLatch(1);
        var worker=java.util.concurrent.Executors.newSingleThreadExecutor();
        try {
            var future=worker.submit(()->tx.execute(t->{
                devices.findById(tablet.id()).orElseThrow();loaded.countDown();
                try {if(!blocked.await(5,java.util.concurrent.TimeUnit.SECONDS))throw new IllegalStateException("timeout");}catch(InterruptedException e){throw new IllegalStateException(e);}
                registry.action(tablet.id(),actor,"unblock","unblock after committed block");return null;
            }));
            assertTrue(loaded.await(5,java.util.concurrent.TimeUnit.SECONDS));
            tx.execute(t->registry.action(tablet.id(),actor,"block","block"));blocked.countDown();future.get(5,java.util.concurrent.TimeUnit.SECONDS);
            assertEquals(1,devices.findById(tablet.id()).orElseThrow().getStatusVersion());
            assertEquals("APPROVED",devices.findById(tablet.id()).orElseThrow().getStatus());
        } finally {blocked.countDown();worker.shutdownNow();}
    }

    @Test void queuedReviewerCannotOverwriteACommittedApproval() throws Exception {
        var tablet=register();tx.execute(t->registry.action(tablet.id(),actor,"approve","approved"));
        var lease=tx.execute(t->registry.heartbeat(account,tablet.id(),"s".repeat(43),new TabletContracts.Beat(1,"1"))).lease();
        tx.execute(t->registry.action(tablet.id(),actor,"block","lost"));
        var item=new AttendanceSyncItemRequest("review-race",UUID.randomUUID(),AttendanceType.IN,signer.now(),signer.now(),.9,null,"photo","image/jpeg",tablet.id().toString(),null,lease.id(),lease.signature());
        var pending=sync.sync(account,tablet.id(),"s".repeat(43),new AttendanceSyncRequest(List.of(item))).results().getFirst();
        var waiting=new java.util.concurrent.CountDownLatch(1);var decided=new java.util.concurrent.CountDownLatch(1);
        var guarded=spy(registry);
        doAnswer(invocation->{if(Thread.currentThread().getName().equals("review-race")){waiting.countDown();if(!decided.await(5,java.util.concurrent.TimeUnit.SECONDS))throw new IllegalStateException("timeout");}return invocation.callRealMethod();}).when(guarded).lock(tablet.id());
        var service=new TabletSyncService(guarded,devices,submissions,attendance,new ObjectMapper().registerModule(new JavaTimeModule()),new JpaTransactionManager(db),signer,SharedEntityManagerCreator.createSharedEntityManager(db));
        when(attendance.syncTabletLog(any(),any())).thenReturn(new AttendanceSyncItemResponse("record","SYNCED",UUID.randomUUID(),null));
        var worker=java.util.concurrent.Executors.newSingleThreadExecutor(r->new Thread(r,"review-race"));
        try {
            var future=worker.submit(()->service.review(pending.reviewId(),actor,false,"queued reject"));
            assertTrue(waiting.await(5,java.util.concurrent.TimeUnit.SECONDS));
            assertEquals("SYNCED",service.review(pending.reviewId(),actor,true,"approve first").getStatus());
            decided.countDown();assertEquals("SYNCED",future.get(5,java.util.concurrent.TimeUnit.SECONDS).getStatus());
            assertEquals("SYNCED",submissions.findById(pending.reviewId()).orElseThrow().getStatus());
        }finally{decided.countDown();worker.shutdownNow();}
    }

}
