package com.suachuabientan.system_internal.modules.warehouse.scheduler;

import com.suachuabientan.system_internal.modules.warehouse.service.PartService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.warehouse.low-stock-alert.enabled", havingValue = "true", matchIfMissing = true)
public class PartLowStockScheduler {

    private final PartService partService;

    /**
     * Tự động quét và gửi thông báo cảnh báo các linh kiện dưới định mức tồn tối thiểu (min amount)
     * Mặc định chạy vào lúc 08:30 sáng hàng ngày từ Thứ 2 đến Thứ 7 (Asia/Ho_Chi_Minh).
     */
    @Scheduled(cron = "${app.warehouse.low-stock.cron:0 30 8 * * MON-SAT}", zone = "Asia/Ho_Chi_Minh")
    public void scanLowStockParts() {
        log.info("Bắt đầu tiến trình quét tự động các linh kiện chạm/dưới định mức tồn tối thiểu...");
        try {
            int alerted = partService.scanAndNotifyAllLowStockParts();
            log.info("Tiến trình quét hoàn tất. Đã gửi cảnh báo cho {} linh kiện dưới định mức.", alerted);
        } catch (Exception e) {
            log.error("Lỗi trong quá trình quét cảnh báo tồn kho tối thiểu: {}", e.getMessage(), e);
        }
    }
}
