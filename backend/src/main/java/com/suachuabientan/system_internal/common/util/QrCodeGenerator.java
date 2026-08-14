package com.suachuabientan.system_internal.common.util;

import org.springframework.stereotype.Component;

import java.util.UUID;

@Component
public class QrCodeGenerator {
    private static final String PREFIX = "BOARD-";

    public String generateQrCode() {
        String uuid = UUID.randomUUID().toString().replace("-", "");
        return PREFIX + uuid.substring(0, 8).toUpperCase();
    }

    public boolean isValidBoardQr(String qrCode) {
        return qrCode != null && qrCode.startsWith(PREFIX) && qrCode.length() == 13;
    }
}
