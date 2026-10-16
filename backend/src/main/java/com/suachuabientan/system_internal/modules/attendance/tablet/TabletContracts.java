package com.suachuabientan.system_internal.modules.attendance.tablet;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.UUID;
public final class TabletContracts {
    private TabletContracts() {
    }
    public record Register(@NotNull UUID installationId, @NotBlank @Size(min=43,max=100) String secret,
    @NotBlank @Size(max=100) String name, @Size(max=100) String model, @Size(max=100) String osVersion, @Size(max=100) String appVersion) {
    }
    public record Beat(@Min(0) int pendingCount, @Size(max=100) String appVersion) {
    }
    public record Action(@NotBlank @Size(max=500) String reason) {
    }
    public record Lease(UUID id,UUID deviceId,UUID accountId,Instant issuedAt,Instant expiresAt,long statusVersion,String signature) {
        public static Lease from(TabletLease l) {
            return l==null?null:new Lease(l.getId(),l.getDeviceId(),l.getAccountId(),l.getIssuedAt(),l.getExpiresAt(),l.getStatusVersion(),l.getSignature());
        }
    }
    public record Device(UUID id,UUID accountId,String installationId,String name,String status,String model,String osVersion,String appVersion,Instant lastSeenAt,Instant lastSyncAt,int pendingCount,boolean online) {
    }
    public record Heartbeat(Device device,Instant serverTime,Lease lease,boolean enforcementEnabled) {
    }
}
