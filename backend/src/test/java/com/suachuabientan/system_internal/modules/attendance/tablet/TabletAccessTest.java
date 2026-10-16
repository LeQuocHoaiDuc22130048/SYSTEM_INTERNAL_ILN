package com.suachuabientan.system_internal.modules.attendance.tablet;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.*;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class TabletAccessTest {
    @Test void sharedAccountRequiresDeviceWhenEnforcedAndPersonalAccountDoesNot() {
        var users=mock(UserRepository.class);
        var devices=mock(TabletDeviceRepository.class);
        var service=new TabletDeviceService(devices,mock(TabletLeaseRepository.class),mock(TabletEventRepository.class),users,new TabletLeaseSigner("test-signing-key-with-at-least-32-bytes",Clock.systemUTC()),mock(jakarta.persistence.EntityManager.class));
        ReflectionTestUtils.setField(service,"enforce",true);
        UUID id=UUID.randomUUID();
        var u=new UserEntity();
        u.setId(id);
        u.setRole(UserRole.ATTENDANCE);
        u.setUsername("attendance");
        u.setStatus(UserStatus.ACTIVE);
        u.setIsDeleted(false);
        when(users.findById(id)).thenReturn(Optional.of(u));
        assertThrows(RuntimeException.class,()->service.requireCapture(id,null,null));
        var d=new TabletDevice();
        d.setId(UUID.randomUUID());
        d.setAccountId(id);
        d.setSecretHash(TabletLeaseSigner.hash("secret"));
        d.setStatus("BLOCKED");
        when(devices.findById(d.getId())).thenReturn(Optional.of(d));
        assertThrows(RuntimeException.class,()->service.requireCapture(id,d.getId().toString(),"secret"));
        u.setRole(UserRole.EMPLOYEE);
        u.setUsername("employee");
        assertDoesNotThrow(()->service.requireCapture(id,null,null));
    }
}
