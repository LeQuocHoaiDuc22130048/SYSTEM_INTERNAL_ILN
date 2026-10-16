package com.suachuabientan.system_internal.modules.attendance.tablet;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.suachuabientan.system_internal.modules.attendance.dto.request.*;
import com.suachuabientan.system_internal.modules.attendance.dto.response.*;
import com.suachuabientan.system_internal.modules.attendance.service.AttendanceService;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.*;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.data.domain.*;
import java.time.Duration;
import java.util.*;
@Service
public class TabletSyncService {
    private final TabletDeviceService registry;
    private final TabletDeviceRepository devices;
    private final TabletSubmissionRepository submissions;
    private final AttendanceService attendance;
    private final ObjectMapper json;
    private final TransactionTemplate tx;
    private final TabletLeaseSigner clock;
    private final jakarta.persistence.EntityManager entityManager;
    public TabletSyncService(TabletDeviceService registry,TabletDeviceRepository devices,TabletSubmissionRepository submissions,AttendanceService attendance,ObjectMapper json,PlatformTransactionManager manager,TabletLeaseSigner clock, jakarta.persistence.EntityManager entityManager) {
        this.entityManager=entityManager;
        this.registry=registry;
        this.devices=devices;
        this.submissions=submissions;
        this.attendance=attendance;
        this.json=json;
        this.tx=new TransactionTemplate(manager);
        this.tx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        this.clock=clock;
    }
    public AttendanceSyncResponse sync(UUID account,UUID id,String secret,AttendanceSyncRequest request) {
        registry.authenticate(account,id,secret);
        var results=new ArrayList<AttendanceSyncItemResponse>();
        for(var item:request.logs())try {
            results.add(tx.execute(s->receive(account,id,secret,item)));
        }
        catch(Exception e) {
            if(e instanceof BusinessException business && business.getStatusCode()<500) {
                try {
                    results.add(tx.execute(t->reject(account,id,secret,item,business.getMessage())));
                }
                catch(Exception storageError) {
                    results.add(new AttendanceSyncItemResponse(item.localLogId(),"FAILED",null,"Retain data and retry",null,"UPLOAD_FAILED"));
                }
            }
            else results.add(new AttendanceSyncItemResponse(item.localLogId(),"FAILED",null,"Upload not accepted; retain data and retry",null,"UPLOAD_FAILED"));
        }
        int recorded=(int)results.stream().filter(r->r.status().equals("SYNCED")).count();
        int skipped=(int)results.stream().filter(r->r.status().equals("SKIPPED")).count();
        return new AttendanceSyncResponse(results.size(),recorded,skipped,results.size()-recorded-skipped,results);
    }
    private AttendanceSyncItemResponse reject(UUID account,UUID device,String secret,AttendanceSyncItemRequest item,String reason) {
        var d=registry.lock(device);
        registry.checkIdentity(d,account,secret);
        var existing=submissions.findByDeviceIdAndLocalLogId(device,item.localLogId());
        String hash=TabletLeaseSigner.hash(encode(item));
        if(existing.isPresent()) {
            var previous=existing.get();
            if(!previous.getPayloadHash().equals(hash)) {
                registry.event(d,account,"PAYLOAD_CONFLICT",previous.getId().toString());
                return new AttendanceSyncItemResponse(item.localLogId(),"REJECTED",null,"Immutable submission payload changed",previous.getId(),"PAYLOAD_CHANGED");
            }
            return response(previous);
        }
        var rejected=new TabletSubmission();
        rejected.setId(UUID.randomUUID());
        rejected.setDeviceId(device);
        rejected.setAccountId(account);
        rejected.setLocalLogId(item.localLogId());
        rejected.setPayloadHash(hash);
        rejected.setPayload("{}");
        rejected.setStatus("REJECTED");
        rejected.setError(reason==null?"REJECTED":reason.substring(0,Math.min(reason.length(),500)));
        rejected.setCreatedAt(clock.now());
        rejected.setEmployeeId(item.employeeId());
        rejected.setCapturedAt(item.checkTime());
        rejected.setAttendanceType(item.type().name());
        submissions.saveAndFlush(rejected);
        return response(rejected);
    }
    private AttendanceSyncItemResponse receive(UUID account,UUID id,String secret,AttendanceSyncItemRequest item) {
        var d=registry.lock(id);
        registry.checkIdentity(d,account,secret);
        String payload=encode(item), hash=TabletLeaseSigner.hash(payload);
        var existing=submissions.findByDeviceIdAndLocalLogId(id,item.localLogId());
        if(existing.isPresent()) {
            var prev=existing.get();
            if(!prev.getPayloadHash().equals(hash))throw new BusinessException("PAYLOAD_CHANGED",409);
            if(!"FAILED".equals(prev.getStatus()))return response(prev);
        }
        var submission=existing.orElseGet(()-> {
            var x=new TabletSubmission();
            x.setId(UUID.randomUUID());
            x.setDeviceId(id);
            x.setAccountId(account);
            x.setLocalLogId(item.localLogId());
            x.setPayload(payload);
            x.setPayloadHash(hash);
            x.setCreatedAt(clock.now());
            x.setEmployeeId(item.employeeId());
            x.setCapturedAt(item.checkTime());
            x.setAttendanceType(item.type().name());
            return x;
        });
        if(item.deviceId()!=null&&!item.deviceId().equals(id.toString())&&item.leaseId()!=null)throw TabletDeviceService.error("DEVICE_MISMATCH");
        if(item.leaseId()==null) {
            submission.setStatus("LEGACY_REVIEW");
            submission.setError("Legacy data has no authorization lease; use manual adjustment");
        }
        else {
            TabletLease lease;
            try {
                lease=registry.validateLease(d,item.leaseId(),item.leaseSignature(),item.checkTime());
            }
            catch(BusinessException e) {
                submission.setStatus("REJECTED");
                submission.setError(e.getMessage());
                submission.setPayload("{}");
                submissions.saveAndFlush(submission);
                return response(submission);
            }
            if(!"APPROVED".equals(d.getStatus())||lease.getStatusVersion()!=d.getStatusVersion()) {
                submission.setStatus("PENDING_REVIEW");
            }
            else record(submission,item,account);
        }
        submissions.saveAndFlush(submission);
        d.setLastSyncAt(clock.now());
        devices.save(d);
        return response(submission);
    }
    private void record(TabletSubmission submission,AttendanceSyncItemRequest item,UUID actor) {
        // The legacy record key is global; namespace and hash the immutable device-local key.
        String key="tablet:"+submission.getDeviceId()+":"+TabletLeaseSigner.hash(item.localLogId());
        var normalized=new AttendanceSyncItemRequest(key,item.employeeId(),item.type(),item.checkTime(),item.checkTime(),item.confidenceScore(),item.faceEmbedding(),item.faceImageBase64(),item.imageContentType(),submission.getDeviceId().toString(),item.note(),item.leaseId(),item.leaseSignature());
        var result=attendance.syncTabletLog(normalized,actor);
        if(!"SYNCED".equals(result.status())&&!"SKIPPED".equals(result.status()))throw new BusinessException("FACE_VERIFICATION_FAILED");
        submission.setStatus(result.status());
        submission.setRecordId(result.serverRecordId());
        submission.setError(result.message());
        // Keep receipt/hash, but discard biometric evidence after successful verification.
        submission.setPayload(encode(new AttendanceSyncItemRequest(item.localLogId(),item.employeeId(),item.type(),item.checkTime(),item.mobileCheckTime(),item.confidenceScore(),null,null,item.imageContentType(),item.deviceId(),item.note(),item.leaseId(),item.leaseSignature())));
    }
    public Page<TabletSubmission> reviews(int page) {
        return submissions.findByStatusIn(List.of("PENDING_REVIEW","LEGACY_REVIEW"),PageRequest.of(Math.max(0,page),20,Sort.by("createdAt").ascending()));
    }
    public List<TabletSubmission> own(UUID account,UUID id,String secret,List<UUID> ids) {
        registry.authenticate(account,id,secret);
        if(ids.isEmpty()||ids.size()>50)throw new BusinessException("REVIEW_IDS_REQUIRED",400);
        return submissions.findByDeviceIdAndIdIn(id,ids);
    }
    public TabletSubmission detail(UUID id) {
        return submissions.findById(id).orElseThrow(()->new BusinessException("REVIEW_NOT_FOUND",404));
    }
    public TabletSubmission review(UUID id,UUID actor,boolean approve,String reason) {
        return tx.execute(t-> {
            var initial=detail(id);
            var device=registry.lock(initial.getDeviceId());
            var s=detail(id);
            // Refresh after waiting for the device lock so a queued reviewer sees the committed decision.
            entityManager.refresh(s, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
            if(!List.of("PENDING_REVIEW","LEGACY_REVIEW").contains(s.getStatus()))return s;
            if(approve) {
                if("LEGACY_REVIEW".equals(s.getStatus()))throw new BusinessException("LEGACY_REQUIRES_MANUAL_ADJUSTMENT",409);
                if(s.getCreatedAt().isBefore(clock.now().minus(Duration.ofDays(30))))throw new BusinessException("REVIEW_EVIDENCE_EXPIRED",409);
                var item=decode(s.getPayload());
                registry.validateLease(device,item.leaseId(),item.leaseSignature(),item.checkTime());
                record(s,item,s.getAccountId());
            }
            else {
                s.setStatus("REJECTED");
                s.setError("Rejected by administrator");
                s.setPayload("{}");
            }
            s.setReviewedBy(actor);
            s.setReviewedAt(clock.now());
            s.setReason(reason);
            registry.event(device,actor,approve?"REVIEW_APPROVED":"REVIEW_REJECTED",id+": "+reason);
            return submissions.saveAndFlush(s);
        });
    }
    public record ReviewView(UUID id,UUID deviceId,UUID accountId,String localLogId,String status,java.time.Instant createdAt,UUID employeeId,java.time.Instant capturedAt,String attendanceType,String error,String reason,UUID recordId,String faceImageBase64,String imageContentType) {
    }
    public ReviewView reviewView(TabletSubmission s,boolean evidence) {
        String image=null,contentType=null;
        if(evidence && List.of("PENDING_REVIEW","LEGACY_REVIEW").contains(s.getStatus()) && !s.getCreatedAt().isBefore(clock.now().minus(Duration.ofDays(30)))) {
            var item=decode(s.getPayload());
            image=item.faceImageBase64();
            contentType=item.imageContentType();
        }
        return new ReviewView(s.getId(),s.getDeviceId(),s.getAccountId(),s.getLocalLogId(),s.getStatus(),s.getCreatedAt(),s.getEmployeeId(),s.getCapturedAt(),s.getAttendanceType(),s.getError(),s.getReason(),s.getRecordId(),image,contentType);
    }
    public org.springframework.data.domain.Page<ReviewView> reviewPage(int page) {
        return reviews(page).map(s->reviewView(s,false));
    }
    @org.springframework.scheduling.annotation.Scheduled(cron="0 0 3 * * *",zone="Asia/Ho_Chi_Minh")
    public void purgeExpiredEvidence() {
        for(;;) {
            var old=submissions.findByCreatedAtBeforeAndStatusIn(clock.now().minus(Duration.ofDays(30)),List.of("PENDING_REVIEW","LEGACY_REVIEW"),PageRequest.of(0,50));
            if(old.isEmpty())return;
            for(var candidate:old)tx.executeWithoutResult(t-> {
                registry.lock(candidate.getDeviceId());
                var current=detail(candidate.getId());
                if(List.of("PENDING_REVIEW","LEGACY_REVIEW").contains(current.getStatus())) {
                    current.setPayload("{}");
                    current.setStatus("REJECTED");
                    current.setError("REVIEW_EVIDENCE_EXPIRED: manual adjustment required");
                    submissions.saveAndFlush(current);
                }
            });
        }
    }
    private AttendanceSyncItemResponse response(TabletSubmission s) {
        return new AttendanceSyncItemResponse(s.getLocalLogId(),s.getStatus().equals("LEGACY_REVIEW")?"PENDING_REVIEW":s.getStatus(),s.getRecordId(),s.getError(),s.getId(),s.getStatus().equals("REJECTED")?"REJECTED":null);
    }
    private String encode(Object value) {
        try {
            return json.writeValueAsString(value);
        }
        catch(Exception e) {
            throw new IllegalArgumentException("INVALID_SUBMISSION",e);
        }
    }
    private AttendanceSyncItemRequest decode(String value) {
        try {
            return json.readValue(value,AttendanceSyncItemRequest.class);
        }
        catch(Exception e) {
            throw new IllegalArgumentException("INVALID_SUBMISSION",e);
        }
    }
}
