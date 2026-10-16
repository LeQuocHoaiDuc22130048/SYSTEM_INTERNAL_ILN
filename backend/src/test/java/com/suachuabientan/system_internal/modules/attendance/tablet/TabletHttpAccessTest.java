package com.suachuabientan.system_internal.modules.attendance.tablet;
import com.suachuabientan.system_internal.modules.attendance.controller.AttendanceController;
import com.suachuabientan.system_internal.modules.attendance.service.*;
import com.suachuabientan.system_internal.config.SecurityConfig;
import com.suachuabientan.system_internal.common.util.JwtUtil;
import com.suachuabientan.system_internal.security.filter.JwtAuthFilter;
import com.suachuabientan.system_internal.security.service.UserDetailsServiceImpl;
import com.suachuabientan.system_internal.security.model.CustomUserDetails;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.MockMvc;
import jakarta.servlet.FilterChain;
import java.util.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
@WebMvcTest( {
    AttendanceController.class,TabletDeviceController.class
}) @Import({SecurityConfig.class, TabletCaptureService.class})
class TabletHttpAccessTest {
    @Autowired MockMvc mvc;
    @MockBean AttendanceService attendance;
    @MockBean FaceRecognitionMonitoringService monitoring;
    @MockBean TabletDeviceService registry;
    @MockBean TabletSyncService sync;
    @MockBean JwtAuthFilter jwt;
    @MockBean JwtUtil tokens;
    @MockBean UserDetailsServiceImpl users;
    CustomUserDetails principal;
    @BeforeEach void setup()throws Exception {
        doAnswer(i-> {
            ((FilterChain)i.getArgument(2)).doFilter(i.getArgument(0),i.getArgument(1));
            return null;
        }).when(jwt).doFilter(any(),any(),any());
        var u=new UserEntity();
        u.setId(UUID.randomUUID());
        u.setUsername("attendance");
        u.setRole(UserRole.ATTENDANCE);
        u.setStatus(UserStatus.ACTIVE);
        principal=new CustomUserDetails(u,Set.of(),Set.of("ATTENDANCE_KIOSK_USE","ATTENDANCE_CHECK_SELF"));
        doThrow(TabletDeviceService.error("DEVICE_ID_REQUIRED")).when(registry).requireCapture(any(),isNull(),isNull());
    }
    @Test void allCaptureRoutesConsultDevicePolicy()throws Exception {
        for(String path:List.of("/face-identify","/face-check","/check")) {
            mvc.perform(post("/api/v1/attendance"+path).with(user(principal)).contentType("application/json").content("{\"faceImageBase64\":\"photo\",\"imageContentType\":\"image/jpeg\"}" )).andExpect(status().isForbidden());
        }
        verifyNoInteractions(attendance);
    }
    @Test void managerCannotManageOrReviewTabletEvenWithDevicePermission()throws Exception {
        mvc.perform(get("/api/v1/attendance/devices").with(user("manager").roles("MANAGER"))).andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/attendance/devices/reviews").with(user("manager").roles("MANAGER"))).andExpect(status().isForbidden());
    }
    @Test void adminCanListTablets()throws Exception {
        mvc.perform(get("/api/v1/attendance/devices").with(user("admin").authorities(new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_ADMIN"),new org.springframework.security.core.authority.SimpleGrantedAuthority("DEVICE_VIEW")))).andExpect(status().isOk());
    }
    @Test void adminWithRevokedDeviceViewCannotReadTablets()throws Exception {
        mvc.perform(get("/api/v1/attendance/devices").with(user("admin").roles("ADMIN"))).andExpect(status().isForbidden());
    }
}
