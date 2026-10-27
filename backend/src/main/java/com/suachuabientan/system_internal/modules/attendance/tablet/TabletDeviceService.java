package com.suachuabientan.system_internal.modules.attendance.tablet;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;
@Service @RequiredArgsConstructor
public class TabletDeviceService {
    private final TabletDeviceRepository devices;
    private final TabletLeaseRepository leases;
    private final TabletEventRepository events;
    private final UserRepository users;
    private final TabletLeaseSigner signer;
    private final jakarta.persistence.EntityManager entityManager;
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private com.suachuabientan.system_internal.modules.attendance.service.AttendanceTabletMonitoringService monitoringService;
    @Value("${app.attendance.tablets.enforce:false}") private boolean enforce;
    public boolean enforced() {
        return enforce;
    }
    public boolean attendanceAccount(UUID account) {
        var u=users.findById(account).orElseThrow(()->error("ACCOUNT_NOT_FOUND"));
        return u.getRole()==UserRole.ATTENDANCE || "attendance".equalsIgnoreCase(u.getUsername());
    }
    public void requireAccount(UUID account) {
        var u=users.findById(account).orElseThrow(()->error("ACCOUNT_NOT_FOUND"));
        if(!u.isActive() || !attendanceAccount(account)) throw error("ATTENDANCE_ACCOUNT_REQUIRED");
    }
    @Transactional public TabletContracts.Device register(UUID account,TabletContracts.Register r) {
        requireAccount(account);
        var existing=devices.findByInstallationId(r.installationId().toString());
        if(existing.isPresent()) {
            var d=existing.get();
            checkIdentity(d,account,r.secret());
            return view(d);
        }
        var d=new TabletDevice();
        d.setId(UUID.randomUUID());
        d.setAccountId(account);
        d.setInstallationId(r.installationId().toString());
        d.setSecretHash(TabletLeaseSigner.hash(r.secret()));
        d.setName(r.name());
        d.setModel(r.model());
        d.setOsVersion(r.osVersion());
        d.setAppVersion(r.appVersion());
        d.setStatus("PENDING");
        d.setCreatedAt(signer.now());
        devices.saveAndFlush(d);
        event(d,account,"REGISTER","Tablet registered");
        return view(d);
    }
    public TabletDevice authenticate(UUID account,UUID id,String secret) {
        requireAccount(account);
        var d=devices.findById(id).orElseThrow(()->error("DEVICE_NOT_REGISTERED"));
        checkIdentity(d,account,secret);
        return d;
    }
    public TabletDevice lock(UUID id) {
        var device = devices.lock(id).orElseThrow(()->error("DEVICE_NOT_REGISTERED"));
        // OSIV or a preliminary read may have cached an older version before the lock was acquired.
        entityManager.refresh(device, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        return device;
    }
    public void checkIdentity(TabletDevice d,UUID account,String secret) {
        if(!d.getAccountId().equals(account)||secret==null||!TabletLeaseSigner.equal(d.getSecretHash(),TabletLeaseSigner.hash(secret)))throw error("DEVICE_IDENTITY_INVALID");
    }
    @Transactional public TabletContracts.Heartbeat heartbeat(UUID account,UUID id,String secret,TabletContracts.Beat request) {
        requireAccount(account);
        var d=lock(id);
        checkIdentity(d,account,secret);
        d.setLastSeenAt(signer.now());
        d.setPendingCount(request.pendingCount());
        d.setAppVersion(request.appVersion());
        TabletLease l=null;
        if("APPROVED".equals(d.getStatus())) {
            l=leases.save(signer.issue(id,account,d.getStatusVersion()));
            if(monitoringService != null) {
                monitoringService.onHeartbeatReceived(id);
            }
        }
        return new TabletContracts.Heartbeat(view(d),signer.now(),TabletContracts.Lease.from(l),enforce);
    }
    @Transactional public TabletContracts.Device action(UUID id,UUID actor,String action,String reason) {
        var initial=devices.findById(id).orElseThrow(()->error("DEVICE_NOT_REGISTERED"));
        // Serialize approvals for the account even when different device rows are selected.
        users.findForFieldWorkUpdate(initial.getAccountId()).orElseThrow(()->error("ACCOUNT_NOT_FOUND"));
        var d=lock(id);
        if(action.equals("block")) {
            d.setStatus("BLOCKED");
            d.setStatusVersion(d.getStatusVersion()+1);
        }
        else if(action.equals("approve")||action.equals("unblock")) {
            for(var other:devices.findByAccountId(d.getAccountId())) if(!other.getId().equals(id)&&"APPROVED".equals(other.getStatus())) {
                var old=lock(other.getId());
                old.setStatus("BLOCKED");
                old.setStatusVersion(old.getStatusVersion()+1);
                event(old,actor,"REPLACED",reason);
            }
            devices.flush();
            d.setStatus("APPROVED");
        }
        else throw error("INVALID_DEVICE_ACTION");
        devices.saveAndFlush(d);
        event(d,actor,action.toUpperCase(Locale.ROOT),reason);
        return view(d);
    }
    public TabletLease validateLease(TabletDevice d,UUID leaseId,String signature,java.time.Instant captured) {
        if(leaseId==null)throw error("LEASE_REQUIRED");
        var l=leases.findById(leaseId).orElseThrow(()->error("LEASE_INVALID"));
        if(!signer.valid(l,d.getId(),d.getAccountId(),captured,signature))throw error("LEASE_INVALID");
        return l;
    }
    @Transactional public void requireCapture(UUID account,String id,String secret) {
        if(!enforce||!attendanceAccount(account))return;
        requireAccount(account);
        var d=lock(parseId(id));
        checkIdentity(d,account,secret);
        if(!"APPROVED".equals(d.getStatus()))throw error("DEVICE_NOT_APPROVED");
    }
    public TabletContracts.Device view(TabletDevice d) {
        return new TabletContracts.Device(d.getId(),d.getAccountId(),d.getInstallationId(),d.getName(),d.getStatus(),d.getModel(),d.getOsVersion(),d.getAppVersion(),d.getLastSeenAt(),d.getLastSyncAt(),d.getPendingCount(),d.getLastSeenAt()!=null&&d.getLastSeenAt().isAfter(signer.now().minusSeconds(180)));
    }
    public TabletContracts.Device detail(UUID id) {
        return view(devices.findById(id).orElseThrow(()->error("DEVICE_NOT_REGISTERED")));
    }
    public List<TabletContracts.Device> list() {
        return devices.findAll(org.springframework.data.domain.Sort.by("createdAt").descending()).stream().map(this::view).toList();
    }
    public List<TabletEvent> events(UUID id) {
        return events.findTop100ByDeviceIdOrderByOccurredAtDesc(id);
    }
    public void event(TabletDevice d,UUID actor,String action,String reason) {
        var e=new TabletEvent();
        e.setId(UUID.randomUUID());
        e.setDeviceId(d.getId());
        e.setActorId(actor);
        e.setAction(action);
        e.setReason(reason==null?null:reason.substring(0,Math.min(reason.length(),500)));
        e.setOccurredAt(signer.now());
        events.save(e);
    }
    public static UUID parseId(String id) {
        try {
            return UUID.fromString(id);
        }
        catch(Exception e) {
            throw error("DEVICE_ID_REQUIRED");
        }
    }
    public static BusinessException error(String code) {
        return new BusinessException(code,403);
    }
}
