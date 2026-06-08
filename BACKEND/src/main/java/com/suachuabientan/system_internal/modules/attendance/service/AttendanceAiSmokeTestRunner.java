package com.suachuabientan.system_internal.modules.attendance.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;
import java.util.List;
import java.util.Map;

@Slf4j
@Component
@RequiredArgsConstructor
public class AttendanceAiSmokeTestRunner implements ApplicationRunner {
    private static final TypeReference<List<Double>> DOUBLE_LIST = new TypeReference<>() {};

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    @Value("${app.face-recognition.base-url:http://127.0.0.1:5000}")
    private String aiBaseUrl;

    @Value("${app.attendance.ai-smoke-test.enabled:${ATTENDANCE_AI_SMOKE_TEST_ENABLED:true}}")
    private boolean enabled;

    @Value("${app.attendance.ai-smoke-test.fail-fast:${ATTENDANCE_AI_SMOKE_TEST_FAIL_FAST:true}}")
    private boolean failFast;

    @Value("${app.attendance.ai-smoke-test.known-good-image:${ATTENDANCE_AI_SMOKE_KNOWN_GOOD:}}")
    private String knownGoodImagePath;

    @Value("${app.attendance.ai-smoke-test.expected-embedding:${ATTENDANCE_AI_SMOKE_EXPECTED_EMBEDDING:}}")
    private String expectedEmbeddingPath;

    @Value("${app.attendance.ai-smoke-test.live-image:${ATTENDANCE_AI_SMOKE_LIVE_IMAGE:}}")
    private String liveImagePath;

    @Value("${app.attendance.ai-smoke-test.spoof-image:${ATTENDANCE_AI_SMOKE_SPOOF_IMAGE:}}")
    private String spoofImagePath;

    @Value("${app.attendance.ai-smoke-test.blurry-image:${ATTENDANCE_AI_SMOKE_BLURRY_IMAGE:}}")
    private String blurryImagePath;

    @Value("${app.attendance.ai-smoke-test.dark-image:${ATTENDANCE_AI_SMOKE_DARK_IMAGE:}}")
    private String darkImagePath;

    @Value("${app.attendance.ai-smoke-test.embedding-dimension:${ATTENDANCE_AI_SMOKE_EMBEDDING_DIMENSION:512}}")
    private int embeddingDimension;

    @Value("${app.attendance.ai-smoke-test.min-expected-embedding-cosine:${ATTENDANCE_AI_SMOKE_MIN_EMBEDDING_COSINE:0.995}}")
    private double minExpectedEmbeddingCosine;

    @Value("${app.attendance.face.match-threshold}")
    private double verifyThreshold;

    @Override
    public void run(ApplicationArguments args) {
        if (!enabled) {
            log.info("Attendance AI smoke test is disabled");
            return;
        }

        try {
            runSmokeTests();
            log.info("Attendance AI smoke test passed");
        } catch (Exception error) {
            if (failFast) {
                throw new IllegalStateException("Attendance AI smoke test failed: " + error.getMessage(), error);
            }
            log.error("Attendance AI smoke test failed: {}", error.getMessage(), error);
        }
    }

    private void runSmokeTests() throws IOException {
        requireFile(knownGoodImagePath, "known-good image");
        requireFile(expectedEmbeddingPath, "expected embedding");
        requireFile(liveImagePath, "live image");
        requireFile(spoofImagePath, "spoof image");

        List<Double> knownGoodEmbedding = encode(knownGoodImagePath);
        assertEmbeddingShape(knownGoodEmbedding);
        assertExpectedEmbedding(knownGoodEmbedding);
        assertVerify(knownGoodEmbedding, knownGoodImagePath);
        assertQuality(knownGoodImagePath, true);
        assertLiveness(liveImagePath, true);
        assertLiveness(spoofImagePath, false);

        if (StringUtils.hasText(blurryImagePath)) {
            requireFile(blurryImagePath, "blurry image");
            assertQuality(blurryImagePath, false);
        }
        if (StringUtils.hasText(darkImagePath)) {
            requireFile(darkImagePath, "dark image");
            assertQuality(darkImagePath, false);
        }
    }

    @SuppressWarnings("unchecked")
    private List<Double> encode(String imagePath) {
        Map<String, Object> response = post("/api/v1/faces/encode", imageRequest(imagePath), Map.class);
        Object encoding = response.get("encoding");
        if (encoding instanceof List<?> list) {
            return list.stream().map(value -> ((Number) value).doubleValue()).toList();
        }
        throw new BusinessException("AI encode khong tra ve field encoding hop le", 502);
    }

    private void assertVerify(List<Double> enrolledEmbedding, String imagePath) {
        Map<String, Object> response = post(
                "/api/v1/faces/verify",
                Map.of(
                        "enrolledEncoding", enrolledEmbedding,
                        "imageBase64", imageBase64(imagePath),
                        "imageContentType", contentType(imagePath)),
                Map.class);
        boolean matched = Boolean.TRUE.equals(response.get("matched"));
        double confidence = number(response.get("confidence"));
        if (!matched || confidence < verifyThreshold) {
            throw new IllegalStateException(
                    "Face embedding verify failed for known-good image: matched="
                            + matched
                            + ", confidence="
                            + confidence);
        }
    }

    private void assertLiveness(String imagePath, boolean expectedLive) {
        Map<String, Object> response = post("/api/v1/faces/liveness", imageRequest(imagePath), Map.class);
        boolean actualLive = Boolean.TRUE.equals(response.get("live"))
                || Boolean.TRUE.equals(response.get("isLive"));
        if (actualLive != expectedLive) {
            throw new IllegalStateException(
                    "MiniFASNet class direction failed for "
                            + imagePath
                            + ": expectedLive="
                            + expectedLive
                            + ", actualLive="
                            + actualLive
                            + ", response="
                            + response);
        }
    }

    private void assertQuality(String imagePath, boolean expectedPass) {
        Map<String, Object> response = post("/api/v1/faces/quality", imageRequest(imagePath), Map.class);
        boolean actualPass = Boolean.TRUE.equals(response.get("passed"))
                || Boolean.TRUE.equals(response.get("pass"));
        if (actualPass != expectedPass) {
            throw new IllegalStateException(
                    "Quality gate smoke test failed for "
                            + imagePath
                            + ": expectedPass="
                            + expectedPass
                            + ", actualPass="
                            + actualPass
                            + ", response="
                            + response);
        }
    }

    private void assertEmbeddingShape(List<Double> embedding) {
        if (embedding.size() != embeddingDimension) {
            throw new IllegalStateException(
                    "Face embedding dimension mismatch: expected="
                            + embeddingDimension
                            + ", actual="
                            + embedding.size());
        }
    }

    private void assertExpectedEmbedding(List<Double> actualEmbedding) throws IOException {
        List<Double> expectedEmbedding = objectMapper.readValue(
                Files.readString(Path.of(expectedEmbeddingPath)),
                DOUBLE_LIST);
        if (expectedEmbedding.size() != embeddingDimension) {
            throw new IllegalStateException(
                    "Expected embedding dimension mismatch: expected="
                            + embeddingDimension
                            + ", actual="
                            + expectedEmbedding.size());
        }
        double cosine = cosineSimilarity(actualEmbedding, expectedEmbedding);
        if (cosine < minExpectedEmbeddingCosine) {
            throw new IllegalStateException(
                    "Face embedding drift detected: cosine="
                            + cosine
                            + ", threshold="
                            + minExpectedEmbeddingCosine);
        }
    }

    private Map<String, Object> imageRequest(String imagePath) {
        return Map.of(
                "imageBase64", imageBase64(imagePath),
                "imageContentType", contentType(imagePath));
    }

    private String imageBase64(String imagePath) {
        try {
            return Base64.getEncoder().encodeToString(Files.readAllBytes(Path.of(imagePath)));
        } catch (IOException error) {
            throw new IllegalStateException("Khong doc duoc anh smoke test: " + imagePath, error);
        }
    }

    private String contentType(String imagePath) {
        String lower = imagePath.toLowerCase();
        if (lower.endsWith(".png")) return "image/png";
        return "image/jpeg";
    }

    private <T> T post(String path, Object request, Class<T> responseType) {
        try {
            return restTemplate.postForObject(aiBaseUrl + path, request, responseType);
        } catch (RestClientException error) {
            throw new IllegalStateException("Khong goi duoc AI smoke endpoint " + path + ": " + error.getMessage(), error);
        }
    }

    private void requireFile(String path, String label) {
        if (!StringUtils.hasText(path)) {
            throw new IllegalStateException("Thieu cau hinh " + label + " cho Attendance AI smoke test");
        }
        if (!Files.isRegularFile(Path.of(path))) {
            throw new IllegalStateException("Khong tim thay " + label + ": " + path);
        }
    }

    private double number(Object value) {
        return value instanceof Number number ? number.doubleValue() : -1;
    }

    private double cosineSimilarity(List<Double> a, List<Double> b) {
        if (a.size() != b.size() || a.isEmpty()) return -1;
        double dot = 0;
        double normA = 0;
        double normB = 0;
        for (int i = 0; i < a.size(); i++) {
            double av = a.get(i) == null ? 0 : a.get(i);
            double bv = b.get(i) == null ? 0 : b.get(i);
            dot += av * bv;
            normA += av * av;
            normB += bv * bv;
        }
        if (normA == 0 || normB == 0) return -1;
        return dot / (Math.sqrt(normA) * Math.sqrt(normB));
    }
}
