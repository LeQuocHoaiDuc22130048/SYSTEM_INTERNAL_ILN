package com.suachuabientan.system_internal.modules.attendance.tablet;
import com.suachuabientan.system_internal.common.dto.ApiResponse;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import java.util.*;
@RestController @RequestMapping("/api/v1/attendance/devices") @RequiredArgsConstructor
public class TabletDeviceController {
    private final TabletDeviceService service;
    private final TabletSyncService sync;
    @PostMapping("/register") @PreAuthorize("hasAuthority('ATTENDANCE_KIOSK_USE') or hasRole('SUPER_ADMIN')")
    public ApiResponse<TabletContracts.Device> register(@AuthenticationPrincipal CustomUserDetails user,@Valid @RequestBody TabletContracts.Register request) {
        return ApiResponse.created(service.register(user.getUserId(),request));
    }
    @PostMapping("/heartbeat") @PreAuthorize("hasAuthority('ATTENDANCE_KIOSK_USE') or hasRole('SUPER_ADMIN')")
    public ApiResponse<TabletContracts.Heartbeat> heartbeat(@AuthenticationPrincipal CustomUserDetails user,@RequestHeader("X-Attendance-Device-Id") UUID id,@RequestHeader("X-Attendance-Device-Secret") String secret,@Valid @RequestBody TabletContracts.Beat request) {
        return ApiResponse.success(service.heartbeat(user.getUserId(),id,secret,request));
    }
    @GetMapping("/me") @PreAuthorize("hasAuthority('ATTENDANCE_KIOSK_USE') or hasRole('SUPER_ADMIN')")
    public ApiResponse<TabletContracts.Device> me(@AuthenticationPrincipal CustomUserDetails user,@RequestHeader("X-Attendance-Device-Id") UUID id,@RequestHeader("X-Attendance-Device-Secret") String secret) {
        return ApiResponse.success(service.view(service.authenticate(user.getUserId(),id,secret)));
    }
    @GetMapping @PreAuthorize("hasRole('SUPER_ADMIN') or (hasRole('ADMIN') and hasAuthority('DEVICE_VIEW'))") public ApiResponse<List<TabletContracts.Device>> list() {
        return ApiResponse.success(service.list());
    }
    @GetMapping("/{id}") @PreAuthorize("hasRole('SUPER_ADMIN') or (hasRole('ADMIN') and hasAuthority('DEVICE_VIEW'))") public ApiResponse<TabletContracts.Device> detail(@PathVariable UUID id) {
        return ApiResponse.success(service.detail(id));
    }
    @PostMapping("/{id}/{action:approve|block|unblock}") @PreAuthorize("hasRole('SUPER_ADMIN') or (hasRole('ADMIN') and hasAuthority('DEVICE_STATUS_UPDATE'))")
    public ApiResponse<TabletContracts.Device> action(@PathVariable UUID id,@PathVariable String action,@AuthenticationPrincipal CustomUserDetails user,@Valid @RequestBody TabletContracts.Action request) {
        return ApiResponse.success(service.action(id,user.getUserId(),action,request.reason()));
    }
    @GetMapping("/{id}/events") @PreAuthorize("hasRole('SUPER_ADMIN') or (hasRole('ADMIN') and hasAuthority('DEVICE_VIEW'))") public ApiResponse<List<TabletEvent>> events(@PathVariable UUID id) {
        return ApiResponse.success(service.events(id));
    }
    @GetMapping("/reviews") @PreAuthorize("hasRole('SUPER_ADMIN') or (hasRole('ADMIN') and hasAuthority('DEVICE_VIEW'))") public ApiResponse<org.springframework.data.domain.Page<TabletSyncService.ReviewView>> reviews(@RequestParam(defaultValue="0") int page) {
        return ApiResponse.success(sync.reviewPage(page));
    }
    @GetMapping("/reviews/{id}") @PreAuthorize("hasRole('SUPER_ADMIN') or (hasRole('ADMIN') and hasAuthority('DEVICE_VIEW'))") public ApiResponse<TabletSyncService.ReviewView> review(@PathVariable UUID id) {
        return ApiResponse.success(sync.reviewView(sync.detail(id),true));
    }
    @PostMapping("/reviews/{id}/{action:approve|reject}") @PreAuthorize("hasRole('SUPER_ADMIN') or (hasRole('ADMIN') and hasAuthority('ATTENDANCE_RECORD_UPDATE'))")
    public ApiResponse<TabletSubmission> reviewAction(@PathVariable UUID id,@PathVariable String action,@AuthenticationPrincipal CustomUserDetails user,@Valid @RequestBody TabletContracts.Action request) {
        return ApiResponse.success(sync.review(id,user.getUserId(),action.equals("approve"),request.reason()));
    }
    @GetMapping("/me/reviews") @PreAuthorize("hasAuthority('ATTENDANCE_KIOSK_USE') or hasRole('SUPER_ADMIN')")
    public ApiResponse<List<TabletSubmission>> ownReviews(@RequestParam List<UUID> ids,@AuthenticationPrincipal CustomUserDetails user,@RequestHeader("X-Attendance-Device-Id") UUID id,@RequestHeader("X-Attendance-Device-Secret") String secret) {
        return ApiResponse.success(sync.own(user.getUserId(),id,secret,ids));
    }
}
