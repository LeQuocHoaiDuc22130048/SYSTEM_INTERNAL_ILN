package com.suachuabientan.system_internal.modules.attendance.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.Base64;
import java.util.Map;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class FaceRecognitionService {
    private static final int MAX_IMAGE_BYTES = 2_000_000;

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    @Value("${app.face-recognition.base-url:http://127.0.0.1:5000}")
    private String baseUrl;

    public String enroll(String faceImageBase64, String imageContentType) {
        List<Double> encoding = encode(faceImageBase64, imageContentType);
        return serializeEncoding(encoding);
    }

    public String serializeEncoding(List<Double> encoding) {
        try {
            return objectMapper.writeValueAsString(encoding);
        } catch (JsonProcessingException ex) {
            throw new BusinessException("Khong the luu face embedding", 500);
        }
    }

    public String enrollAverage(List<FaceImageSample> samples) {
        return serializeEncoding(encodeAverage(samples));
    }

    public List<Double> encodeAverage(List<FaceImageSample> samples) {
        if (samples == null || samples.isEmpty()) {
            throw new BusinessException("Can it nhat mot mau khuon mat de dang ky");
        }
        List<List<Double>> encodings = samples.stream()
                .map(sample -> encode(sample.faceImageBase64(), sample.imageContentType()))
                .toList();
        return averageAndNormalize(encodings);
    }

    public List<Double> encode(String faceImageBase64, String imageContentType) {
        FaceImageRequest request = validImageRequest(faceImageBase64, imageContentType);
        Map<String, Object> response = post("/api/v1/faces/encode", imageRequestBody(request));
        List<Double> encoding = readDoubleList(response.get("encoding"));
        if (encoding.isEmpty()) {
            throw new BusinessException("Dich vu AI khong tra ve face embedding hop le", 502);
        }
        return encoding;
    }

    public FaceVerificationResult verify(
            String enrolledEncoding,
            String faceImageBase64,
            String imageContentType) {
        FaceImageRequest imageRequest = validImageRequest(faceImageBase64, imageContentType);
        Map<String, Object> response = post("/api/v1/faces/verify", Map.of(
                "enrolledEncoding", readEncoding(enrolledEncoding),
                "imageBase64", imageRequest.imageBase64(),
                "imageContentType", imageRequest.imageContentType()));
        Object matched = response.get("matched");
        Object confidence = response.get("confidence");
        if (!(matched instanceof Boolean matchedValue) || !(confidence instanceof Number confidenceValue)) {
            throw new BusinessException("Dich vu AI khong tra ve ket qua xac minh hop le", 502);
        }
        return new FaceVerificationResult(matchedValue, confidenceValue.doubleValue());
    }

    public double cosineSimilarity(String enrolledEncoding, List<Double> candidateEncoding) {
        return cosine(readEncoding(enrolledEncoding), candidateEncoding);
    }

    private List<Double> readEncoding(String enrolledEncoding) {
        try {
            List<Double> encoding = objectMapper.readValue(enrolledEncoding, new TypeReference<>() {
            });
            if (encoding == null || encoding.isEmpty()) {
                throw new BusinessException("Face embedding da dang ky khong hop le", 500);
            }
            return encoding;
        } catch (JsonProcessingException ex) {
            throw new BusinessException("Face embedding da dang ky khong hop le", 500);
        }
    }

    private FaceImageRequest validImageRequest(String imageBase64, String imageContentType) {
        if (!"image/jpeg".equals(imageContentType) && !"image/png".equals(imageContentType)) {
            throw new BusinessException("Chi ho tro anh JPEG hoac PNG");
        }
        try {
            byte[] decoded = Base64.getDecoder().decode(imageBase64);
            if (decoded.length == 0 || decoded.length > MAX_IMAGE_BYTES) {
                throw new BusinessException("Anh khuon mat khong hop le hoac qua lon");
            }
        } catch (IllegalArgumentException ex) {
            throw new BusinessException("Anh khuon mat khong dung dinh dang Base64");
        }
        return new FaceImageRequest(imageBase64, imageContentType);
    }

    private List<Double> averageAndNormalize(List<List<Double>> encodings) {
        int dimension = encodings.getFirst().size();
        if (dimension == 0) {
            throw new BusinessException("Face embedding rong", 502);
        }
        double[] average = new double[dimension];
        for (List<Double> encoding : encodings) {
            if (encoding.size() != dimension) {
                throw new BusinessException("Cac mau face embedding khong cung kich thuoc", 502);
            }
            for (int i = 0; i < dimension; i++) {
                average[i] += encoding.get(i);
            }
        }
        double norm = 0.0;
        for (int i = 0; i < average.length; i++) {
            average[i] /= encodings.size();
            norm += average[i] * average[i];
        }
        norm = Math.sqrt(norm);
        List<Double> normalized = new java.util.ArrayList<>(dimension);
        for (double value : average) {
            normalized.add(norm == 0.0 ? value : value / norm);
        }
        return normalized;
    }

    private double cosine(List<Double> a, List<Double> b) {
        if (a == null || b == null || a.isEmpty() || a.size() != b.size()) {
            return -1.0;
        }
        double dot = 0.0;
        double normA = 0.0;
        double normB = 0.0;
        for (int i = 0; i < a.size(); i++) {
            double x = a.get(i);
            double y = b.get(i);
            dot += x * y;
            normA += x * x;
            normB += y * y;
        }
        if (normA == 0.0 || normB == 0.0) {
            return -1.0;
        }
        return dot / (Math.sqrt(normA) * Math.sqrt(normB));
    }

    private Map<String, Object> imageRequestBody(FaceImageRequest request) {
        return Map.of(
                "imageBase64", request.imageBase64(),
                "imageContentType", request.imageContentType());
    }

    private List<Double> readDoubleList(Object rawValue) {
        if (!(rawValue instanceof List<?> rawList)) {
            return List.of();
        }
        return rawList.stream()
                .filter(Number.class::isInstance)
                .map(Number.class::cast)
                .map(Number::doubleValue)
                .toList();
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> post(String path, Object request) {
        String url = baseUrl.trim() + path;
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set(HttpHeaders.CONNECTION, "close");
            Map<String, Object> response = restTemplate.postForObject(
                    url,
                    new HttpEntity<>(request, headers),
                    Map.class);
            return response == null ? Map.of() : response;
        } catch (HttpStatusCodeException ex) {
            String aiError = aiErrorMessage(ex);
            log.warn("Face recognition service rejected request: {} status={} error={}",
                    url, ex.getStatusCode(), aiError);
            if (ex.getStatusCode().is4xxClientError()) {
                throw new BusinessException(
                        "Dich vu AI khong phat hien duoc khuon mat. Vui long dua mat ro hon vao khung hinh",
                        400);
            }
            throw new BusinessException("Dich vu AI xu ly loi: " + aiError, 502);
        } catch (RestClientException ex) {
            log.warn("Face recognition service call failed: {} ({})", url, ex.getMessage());
            throw new BusinessException("Khong the ket noi dich vu nhan dien khuon mat", 502);
        }
    }

    private String aiErrorMessage(HttpStatusCodeException ex) {
        try {
            Map<String, Object> body = objectMapper.readValue(ex.getResponseBodyAsString(), new TypeReference<>() {
            });
            Object error = body.get("error");
            return error == null ? ex.getResponseBodyAsString() : error.toString();
        } catch (Exception ignored) {
            return ex.getResponseBodyAsString();
        }
    }

    public record FaceImageRequest(String imageBase64, String imageContentType) {
    }

    public record FaceImageSample(String faceImageBase64, String imageContentType) {
    }

    public record FaceVerificationResult(boolean matched, double confidence) {
    }
}
