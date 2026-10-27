package com.suachuabientan.system_internal.modules.device.service;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class NetworkPingServiceTest {

    private final NetworkPingService pingService = new NetworkPingService();

    @Test
    @DisplayName("Ping localhost 127.0.0.1 phản hồi thành công với latency ms thật")
    void ping_localhost_success() {
        NetworkPingService.PingResult result = pingService.ping("127.0.0.1", null);
        assertTrue(result.isOnline(), "Localhost 127.0.0.1 phải online");
        assertTrue(result.pingMs() >= 1, "Ping ms phải lớn hơn hoặc bằng 1ms");
        assertNotNull(result.message());
    }

    @Test
    @DisplayName("Host rỗng hoặc null trả về offline")
    void ping_emptyHost_returnsOffline() {
        NetworkPingService.PingResult resultNull = pingService.ping(null, null);
        assertFalse(resultNull.isOnline());

        NetworkPingService.PingResult resultEmpty = pingService.ping("   ", null);
        assertFalse(resultEmpty.isOnline());
    }

    @Test
    @DisplayName("Host chứa ký tự nguy hiểm / injection bị chặn và trả về offline an toàn")
    void ping_invalidHost_blockedSafely() {
        NetworkPingService.PingResult result = pingService.ping("127.0.0.1; whoami", null);
        assertFalse(result.isOnline());
        assertTrue(result.message().contains("không hợp lệ"));
    }

    @Test
    @DisplayName("IP không tồn tại trả về offline")
    void ping_unreachableIp_returnsOffline() {
        NetworkPingService.PingResult result = pingService.ping("192.0.2.1", null); // RFC 5737 TEST-NET-1
        assertFalse(result.isOnline());
        assertEquals(0, result.pingMs());
    }
}
