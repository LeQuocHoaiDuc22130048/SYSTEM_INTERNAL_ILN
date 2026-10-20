package com.suachuabientan.system_internal.modules.customer.controller;

import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.modules.customer.dto.CustomerOrderDetailResponse;
import com.suachuabientan.system_internal.modules.customer.dto.PortalTrackRequest;
import com.suachuabientan.system_internal.modules.customer.dto.PortalSupportConfigResponse;
import com.suachuabientan.system_internal.modules.customer.service.CustomerPortalService;
import com.suachuabientan.system_internal.modules.customer.service.PortalSupportConfigService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Portal Public", description = "Cổng tra cứu công khai cho khách hàng")
@RestController
@RequestMapping("/api/v1/portal")
@RequiredArgsConstructor
public class PortalPublicController {

    private final CustomerPortalService portalService;
    private final PortalSupportConfigService supportConfigService;

    @Operation(summary = "Tra cứu nhanh tiến độ đơn hàng bằng mã đơn và số điện thoại")
    @PostMapping("/track")
    public ResponseEntity<ApiResponse<CustomerOrderDetailResponse>> trackOrder(
            @Valid @RequestBody PortalTrackRequest request) {
        return ResponseEntity.ok(ApiResponse.success(portalService.trackOrder(request)));
    }

    @Operation(summary = "Lấy thông tin kênh hỗ trợ (Hotline, Zalo, giờ làm việc)")
    @GetMapping("/support-info")
    public ResponseEntity<ApiResponse<PortalSupportConfigResponse>> getSupportInfo() {
        return ResponseEntity.ok(ApiResponse.success(supportConfigService.getSupportConfig()));
    }
}
