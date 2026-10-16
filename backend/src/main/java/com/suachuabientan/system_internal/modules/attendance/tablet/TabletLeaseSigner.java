package com.suachuabientan.system_internal.modules.attendance.tablet;
import org.springframework.stereotype.Component;
import org.springframework.beans.factory.annotation.*;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.time.*;
import java.util.*;
@Component
public class TabletLeaseSigner {
    private final byte[] key;
    private final Clock clock;
    @Autowired public TabletLeaseSigner(@Value("${app.attendance.tablets.signing-key:${application.security.jwt.secret-key}}") String key) {
        this(key, Clock.systemUTC());
    }
    public TabletLeaseSigner(String key, Clock clock) {
        if(key.length()<32) throw new IllegalArgumentException("Tablet signing key must contain at least 32 characters");
        this.key=key.getBytes(StandardCharsets.UTF_8);
        this.clock=clock;
    }
    public Instant now() {
        return clock.instant();
    }
    public TabletLease issue(UUID device, UUID account, long version) {
        var l=new TabletLease();
        l.setId(UUID.randomUUID());
        l.setDeviceId(device);
        l.setAccountId(account);
        l.setIssuedAt(now().truncatedTo(java.time.temporal.ChronoUnit.MICROS));
        l.setExpiresAt(l.getIssuedAt().plus(Duration.ofHours(24)));
        l.setStatusVersion(version);
        l.setSignature(sign(l));
        return l;
    }
    public boolean valid(TabletLease l, UUID device, UUID account, Instant capturedAt, String signature) {
        return capturedAt!=null && device.equals(l.getDeviceId()) && account.equals(l.getAccountId())
        && !capturedAt.isBefore(l.getIssuedAt()) && capturedAt.isBefore(l.getExpiresAt())
        && !capturedAt.isAfter(now().plusSeconds(30)) && equal(sign(l),signature);
    }
    private String sign(TabletLease l) {
        try {
            var mac=Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key,"HmacSHA256"));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(mac.doFinal(("attendance-tablet-v1|"+l.getId()+"|"+l.getDeviceId()+"|"+l.getAccountId()+"|"+l.getIssuedAt()+"|"+l.getExpiresAt()+"|"+l.getStatusVersion()).getBytes(StandardCharsets.UTF_8)));
        }
        catch(GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }
    public static boolean equal(String a,String b) {
        return a!=null && b!=null && MessageDigest.isEqual(a.getBytes(StandardCharsets.UTF_8),b.getBytes(StandardCharsets.UTF_8));
    }
    public static String hash(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
        }
        catch(NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
