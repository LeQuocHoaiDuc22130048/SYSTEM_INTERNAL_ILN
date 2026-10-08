package com.suachuabientan.system_internal.modules.attendance.service;
import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.modules.attendance.entity.FieldWorkDay;
import com.suachuabientan.system_internal.modules.attendance.repository.FieldWorkDayRepository;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import org.junit.jupiter.api.Test;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class FieldWorkServiceTest {
    private final FieldWorkDayRepository days = mock(FieldWorkDayRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final UUID employeeId = UUID.randomUUID();
    private final LocalDate date = LocalDate.of(2026, 9, 21);
    private final FieldWorkService service = new FieldWorkService(days, users);
    private void setup() {
        when(users.findForFieldWorkUpdate(employeeId)).thenReturn(Optional.of(new UserEntity()));
        when(days.save(any())).thenAnswer(i -> i.getArgument(0));
    }
    @Test void recordsPastDayWithTrimmedNote() {
        setup();
        var result = service.save(employeeId, date, "  Nhà máy ABC  ");
        assertEquals(date, result.workDate());
        assertEquals(employeeId, result.employeeId());
        assertEquals("Nhà máy ABC", result.note());
        verify(days).save(argThat(day -> employeeId.equals(day.getCreatedBy())));
    }
    @Test void updatesAndReactivatesExistingDayWithoutDuplicating() {
        setup();
        FieldWorkDay existing = new FieldWorkDay();
        existing.setId(UUID.randomUUID());
        existing.setEmployeeId(employeeId);
        existing.setWorkDate(date);
        existing.setIsDeleted(true);
        when(days.findByEmployeeIdAndWorkDate(employeeId, date)).thenReturn(Optional.of(existing));
        service.save(employeeId, date, "Địa điểm mới");
        assertFalse(existing.getIsDeleted());
        assertNull(existing.getDeletedAt());
        assertEquals("Địa điểm mới", existing.getNote());
        verify(days).save(existing);
    }
    @Test void listReturnsOnlyOwnActiveDaysAndValidatesRange() {
        when(users.findByIdAndIsDeletedFalse(employeeId)).thenReturn(Optional.of(new UserEntity()));
        FieldWorkDay day = new FieldWorkDay();
        day.setEmployeeId(employeeId);
        day.setWorkDate(date);
        day.setNote("ABC");
        when(days.findByEmployeeIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateAsc(employeeId, date, date))
                .thenReturn(List.of(day));
        assertEquals(1, service.list(employeeId, date, date).size());
        assertThrows(BusinessException.class, () -> service.list(employeeId, date.plusDays(1), date));
    }
    @Test void missingEmployeeCannotRecordDay() {
        assertThrows(BusinessException.class, () -> service.save(employeeId, date, "ABC"));
        verify(days, never()).save(any());
    }
    @Test void uncheckingMissingDayIsIdempotent() {
        when(users.findForFieldWorkUpdate(employeeId)).thenReturn(Optional.of(new UserEntity()));
        service.remove(employeeId, date);
        verify(days, never()).save(any());
    }
    @Test void rejectsFutureDateAndBlankNote() {
        assertThrows(BusinessException.class, () -> service.save(employeeId,
                LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh")).plusDays(1), "ABC"));
        assertThrows(BusinessException.class, () -> service.save(employeeId, date, "  "));
        verify(days, never()).save(any());
    }
    @Test void uncheckingSoftDeletesOwnDay() {
        when(users.findForFieldWorkUpdate(employeeId)).thenReturn(Optional.of(new UserEntity()));
        FieldWorkDay existing = new FieldWorkDay();
        when(days.findByEmployeeIdAndWorkDate(employeeId, date)).thenReturn(Optional.of(existing));
        service.remove(employeeId, date);
        assertTrue(existing.getIsDeleted());
        assertNotNull(existing.getDeletedAt());
        assertEquals(employeeId, existing.getUpdatedBy());
    }
}

