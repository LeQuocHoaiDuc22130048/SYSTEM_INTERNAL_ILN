package com.suachuabientan.system_internal.modules.device.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Slf4j
@Service
public class NetworkPingService {

    private static final Pattern TIME_PATTERN = Pattern.compile("(?:time|thời gian)[=<]([0-9]+)\\s*ms", Pattern.CASE_INSENSITIVE);
    private static final Pattern LESS_THAN_ONE_PATTERN = Pattern.compile("(?:time|thời gian)<1\\s*ms", Pattern.CASE_INSENSITIVE);
    private static final Pattern VALID_HOST_PATTERN = Pattern.compile("^[a-zA-Z0-9.:-]+$");

    public record PingResult(boolean isOnline, int pingMs, String message) {}

    public PingResult ping(String ipAddress, Integer port) {
        if (ipAddress == null || ipAddress.isBlank()) {
            return new PingResult(false, 0, "Địa chỉ IP không được để trống");
        }

        String target = ipAddress.trim();
        if (!VALID_HOST_PATTERN.matcher(target).matches()) {
            return new PingResult(false, 0, "Địa chỉ IP/Host không hợp lệ");
        }

        // 1. Try OS Native ICMP Ping
        PingResult osResult = executeOsPing(target);
        if (osResult.isOnline()) {
            return osResult;
        }

        // 2. Try TCP Socket probe if port is provided or common web/stream ports
        if (port != null && port > 0) {
            PingResult portResult = probeTcpPort(target, port);
            if (portResult.isOnline()) {
                return portResult;
            }
        }

        // 3. Try standard Java InetAddress.isReachable fallback
        PingResult isReachableResult = probeInetAddress(target);
        if (isReachableResult.isOnline()) {
            return isReachableResult;
        }

        return new PingResult(false, 0, "Thiết bị không phản hồi mạng (Timeout)");
    }

    private PingResult executeOsPing(String host) {
        boolean isWindows = System.getProperty("os.name", "").toLowerCase().contains("win");
        ProcessBuilder processBuilder;

        if (isWindows) {
            processBuilder = new ProcessBuilder("ping", "-n", "1", "-w", "1000", host);
        } else {
            processBuilder = new ProcessBuilder("ping", "-c", "1", "-W", "1", host);
        }

        try {
            long startTime = System.currentTimeMillis();
            Process process = processBuilder.start();
            boolean finished = process.waitFor(1500, TimeUnit.MILLISECONDS);

            if (!finished) {
                process.destroyForcibly();
                return new PingResult(false, 0, "Ping tiến trình hết thời gian chờ");
            }

            int exitCode = process.exitValue();
            StringBuilder output = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                }
            }

            if (exitCode == 0) {
                String outStr = output.toString();
                int latency = extractPingMs(outStr);
                if (latency <= 0) {
                    latency = Math.max(1, (int) (System.currentTimeMillis() - startTime));
                }
                return new PingResult(true, latency, "ICMP Ping phản hồi trong " + latency + "ms");
            }
        } catch (Exception e) {
            log.debug("Lỗi khi thực thi lệnh ping OS cho host {}: {}", host, e.getMessage());
        }

        return new PingResult(false, 0, "ICMP Ping thất bại");
    }

    private PingResult probeTcpPort(String host, int port) {
        long startTime = System.currentTimeMillis();
        try (Socket socket = new Socket()) {
            socket.connect(new InetSocketAddress(host, port), 1000);
            int latency = Math.max(1, (int) (System.currentTimeMillis() - startTime));
            return new PingResult(true, latency, "Kết nối TCP port " + port + " thành công trong " + latency + "ms");
        } catch (Exception e) {
            log.debug("Kết nối TCP port {} tới host {} thất bại: {}", port, host, e.getMessage());
            return new PingResult(false, 0, "TCP port " + port + " không phản hồi");
        }
    }

    private PingResult probeInetAddress(String host) {
        long startTime = System.currentTimeMillis();
        try {
            InetAddress address = InetAddress.getByName(host);
            if (address.isReachable(1000)) {
                int latency = Math.max(1, (int) (System.currentTimeMillis() - startTime));
                return new PingResult(true, latency, "InetAddress.isReachable phản hồi trong " + latency + "ms");
            }
        } catch (Exception e) {
            log.debug("Lỗi probe InetAddress cho host {}: {}", host, e.getMessage());
        }
        return new PingResult(false, 0, "InetAddress.isReachable không tới được thiết bị");
    }

    private int extractPingMs(String pingOutput) {
        if (LESS_THAN_ONE_PATTERN.matcher(pingOutput).find()) {
            return 1;
        }

        Matcher matcher = TIME_PATTERN.matcher(pingOutput);
        if (matcher.find()) {
            try {
                return Math.max(1, Integer.parseInt(matcher.group(1)));
            } catch (NumberFormatException ignored) {
            }
        }

        return 0;
    }
}
