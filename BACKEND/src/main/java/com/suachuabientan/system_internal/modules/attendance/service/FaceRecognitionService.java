package com.suachuabientan.system_internal.modules.attendance.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.Base64;
import java.util.List;

@Service
@RequiredArgsConstructor
public class FaceRecognitionService {
    private static final int MAX_IMAGE_BYTES = 2_000_000;

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    @Value("${app.face-recognition.base-url:http://localhost:5000}")
    private String baseUrl;

    public String enroll(String faceImageBase64, String imageContentType) {
        FaceImageRequest request = validImageRequest(faceImageBase64, imageContentType);
        FaceEncodingResponse response = post("/api/v1/faces/encode", request, FaceEncodingResponse.class);
        if (response == null || response.encoding() == null || response.encoding().isEmpty()) {
            throw new BusinessException("Dich vu AI khong tra ve face embedding hop le", 502);
        }
        try {
            return objectMapper.writeValueAsString(response.encoding());
        } catch (JsonProcessingException ex) {
            throw new BusinessException("Khong the luu face embedding", 500);
        }
    }

    public FaceVerificationResult verify(
            String enrolledEncoding,
            String faceImageBase64,
            String imageContentType) {
        FaceImageRequest imageRequest = validImageRequest(faceImageBase64, imageContentType);
        FaceVerifyRequest request = new FaceVerifyRequest(
                readEncoding(enrolledEncoding),
                imageRequest.imageBase64(),
                imageRequest.imageContentType());
        FaceVerifyResponse response = post("/api/v1/faces/verify", request, FaceVerifyResponse.class);
        if (response == null || response.matched() == null || response.confidence() == null) {
            throw new BusinessException("Dich vu AI khong tra ve ket qua xac minh hop le", 502);
        }
        return new FaceVerificationResult(response.matched(), response.confidence());
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

    private <T> T post(String path, Object request, Class<T> responseType) {
        try {
            return restTemplate.postForObject(baseUrl + path, request, responseType);
        } catch (RestClientException ex) {
            throw new BusinessException("Khong the ket noi dich vu nhan dien khuon mat", 502);
        }
    }

    private record FaceImageRequest(String imageBase64, String imageContentType) {
    }

    private record FaceEncodingResponse(List<Double> encoding) {
    }

    private record FaceVerifyRequest(
            List<Double> enrolledEncoding,
            String imageBase64,
            String imageContentType) {
    }

    private record FaceVerifyResponse(Boolean matched, Double confidence) {
    }

    public record FaceVerificationResult(boolean matched, double confidence) {
    }
}
