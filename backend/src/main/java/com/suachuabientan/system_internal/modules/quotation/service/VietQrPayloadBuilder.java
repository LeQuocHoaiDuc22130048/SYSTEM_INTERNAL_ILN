package com.suachuabientan.system_internal.modules.quotation.service;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;

/**
 * Sinh chuỗi QR chuẩn EMVCo / VietQR (Napas 247) để render QR trực tiếp trên client mà không phụ thuộc dịch vụ ảnh ngoài.
 */
public final class VietQrPayloadBuilder {

    private VietQrPayloadBuilder() {
    }

    public static String build(String bankBin, String accountNumber, BigDecimal amount, String transferContent) {
        if (bankBin == null || bankBin.isBlank() || accountNumber == null || accountNumber.isBlank()) {
            return "";
        }
        String cleanBin = bankBin.trim();
        String cleanAccount = accountNumber.trim();

        String bankInfo = tlv("00", cleanBin) + tlv("01", cleanAccount);
        String consumerAccountInfo = tlv("00", "A000000727")
                + tlv("01", bankInfo)
                + tlv("02", "QRIBFTTA");

        StringBuilder payload = new StringBuilder();
        payload.append(tlv("00", "01"));
        payload.append(tlv("01", amount != null && amount.compareTo(BigDecimal.ZERO) > 0 ? "12" : "11"));
        payload.append(tlv("38", consumerAccountInfo));
        payload.append(tlv("53", "704")); // VND
        if (amount != null && amount.compareTo(BigDecimal.ZERO) > 0) {
            payload.append(tlv("54", String.valueOf(amount.longValue())));
        }
        payload.append(tlv("58", "VN"));
        if (transferContent != null && !transferContent.isBlank()) {
            String sanitized = transferContent.trim();
            if (sanitized.length() > 95) {
                sanitized = sanitized.substring(0, 95);
            }
            payload.append(tlv("62", tlv("08", sanitized)));
        }
        payload.append("6304");
        payload.append(crc16Ccitt(payload.toString()));
        return payload.toString();
    }

    private static String tlv(String tag, String value) {
        String safe = value == null ? "" : value;
        return tag + String.format("%02d", safe.length()) + safe;
    }

    private static String crc16Ccitt(String data) {
        int crc = 0xFFFF;
        for (byte b : data.getBytes(StandardCharsets.UTF_8)) {
            crc ^= (b & 0xFF) << 8;
            for (int i = 0; i < 8; i++) {
                if ((crc & 0x8000) != 0) {
                    crc = (crc << 1) ^ 0x1021;
                } else {
                    crc <<= 1;
                }
                crc &= 0xFFFF;
            }
        }
        return String.format("%04X", crc);
    }
}

