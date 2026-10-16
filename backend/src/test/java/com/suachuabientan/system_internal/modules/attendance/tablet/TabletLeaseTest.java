package com.suachuabientan.system_internal.modules.attendance.tablet;
import org.junit.jupiter.api.Test;
import java.time.*;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
class TabletLeaseTest {
    @Test void expiresAtExactlyTwentyFourHoursAndBindsIdentity() {
        var clock = Clock.fixed(Instant.parse("2026-10-16T00:00:00Z"), ZoneOffset.UTC);
        var signer = new TabletLeaseSigner("test-signing-key-with-at-least-32-bytes", clock);
        var device = UUID.randomUUID();
        var account = UUID.randomUUID();
        var lease = signer.issue(device, account, 3);
        assertEquals(clock.instant().plus(Duration.ofHours(24)), lease.getExpiresAt());
        assertTrue(signer.valid(lease, device, account, clock.instant(), lease.getSignature()));
        assertFalse(signer.valid(lease, device, account, lease.getExpiresAt(), lease.getSignature()));
        assertFalse(signer.valid(lease, UUID.randomUUID(), account, clock.instant(), lease.getSignature()));
        assertFalse(signer.valid(lease, device, account, clock.instant().minusSeconds(1), lease.getSignature()));
        assertFalse(signer.valid(lease, device, account, clock.instant(), "forged"));
        lease.setStatusVersion(4);
        assertFalse(signer.valid(lease, device, account, clock.instant(), lease.getSignature()));
    }
    @Test void leaseSignatureSurvivesDatabaseTimestampPrecision() {
        var clock=Clock.fixed(Instant.parse("2026-10-16T00:00:00.123456789Z"),ZoneOffset.UTC);
        var signer=new TabletLeaseSigner("test-signing-key-with-at-least-32-bytes",clock);
        var lease=signer.issue(UUID.randomUUID(),UUID.randomUUID(),0);
        String signature=lease.getSignature();
        // PostgreSQL timestamptz stores microseconds, not Java Instant nanoseconds.
        lease.setIssuedAt(lease.getIssuedAt().truncatedTo(java.time.temporal.ChronoUnit.MICROS));
        lease.setExpiresAt(lease.getExpiresAt().truncatedTo(java.time.temporal.ChronoUnit.MICROS));
        assertTrue(signer.valid(lease,lease.getDeviceId(),lease.getAccountId(),clock.instant(),signature));
    }

}
