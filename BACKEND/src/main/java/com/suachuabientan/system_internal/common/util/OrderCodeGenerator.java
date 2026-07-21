package com.suachuabientan.system_internal.common.util;

import com.suachuabientan.system_internal.modules.repair.repository.RepairOrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@Component
@RequiredArgsConstructor
public class OrderCodeGenerator {
    private final RepairOrderRepository repairOrderRepository;
    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("yyyyMMdd");

    public synchronized String generate() {
        String today = LocalDate.now().format(DATE_FORMAT);
        String prefix = "RO-" + today + "-";

        // Tìm số thứ tự lớn nhất trong ngày hôm nay
        int nextSeq = 1;
        String candidate = prefix + String.format("%03d", nextSeq);

        while (repairOrderRepository.existsByOrderCode(candidate)) {
            nextSeq++;
            candidate = prefix + String.format("%03d", nextSeq);
        }

        return candidate;
    }
}
