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
    private final com.suachuabientan.system_internal.modules.notification.service.NotificationService notifications = mock(com.suachuabientan.system_internal.modules.notification.service.NotificationService.class);
    private final FieldWorkService service = new FieldWorkService(days, users, notifications);
    private void setup() {
        when(users.findForFieldWorkUpdate(employeeId)).thenReturn(Optional.of(new UserEntity()));
        when(days.save(any())).thenAnswer(i -> i.getArgument(0));
        when(days.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));
    }
    @Test void recordsPastDayWithTrimmedNote() {
        setup();
        var result = service.save(employeeId, date, "  Nhà máy ABC  ");
        assertEquals(date, result.workDate());
        assertEquals(employeeId, result.employeeId());
        assertEquals("Nhà máy ABC", result.note());
        verify(days).saveAndFlush(argThat(day -> employeeId.equals(day.getCreatedBy())));
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
        verify(days).saveAndFlush(existing);
    }
    @Test void listReturnsOnlyOwnActiveDaysAndValidatesRange() {
        when(users.findByIdAndIsDeletedFalse(employeeId)).thenReturn(Optional.of(new UserEntity()));
        FieldWorkDay day = new FieldWorkDay();
        day.setEmployeeId(employeeId);
        day.setWorkDate(date);
        day.setNote("ABC");
        when(days.findByEmployeeIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateDesc(employeeId, date, date))
                .thenReturn(List.of(day));
        assertEquals(1, service.list(employeeId, date, date).size());
        assertThrows(BusinessException.class, () -> service.list(employeeId, date.plusDays(1), date));
    }
    @Test void missingEmployeeCannotRecordDay() {
        assertThrows(BusinessException.class, () -> service.save(employeeId, date, "ABC"));
        verify(days, never()).save(any());
        verify(days, never()).saveAndFlush(any());
    }
    @Test void uncheckingMissingDayIsIdempotent() {
        when(users.findForFieldWorkUpdate(employeeId)).thenReturn(Optional.of(new UserEntity()));
        service.remove(employeeId, date);
        verify(days, never()).save(any());
        verify(days, never()).saveAndFlush(any());
    }
    @Test void rejectsFutureDateAndBlankNote() {
        assertThrows(BusinessException.class, () -> service.save(employeeId,
                LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh")).plusDays(1), "ABC"));
        assertThrows(BusinessException.class, () -> service.save(employeeId, date, "  "));
        verify(days, never()).save(any());
        verify(days, never()).saveAndFlush(any());
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
    @Test void newRequestMustWaitForApproval() {
        setup();
        service.save(employeeId, date, "ABC");
        verify(days).saveAndFlush(argThat(day -> "PENDING".equals(day.getStatus())));
    }

    private FieldWorkDay pendingDay() {
        setup();
        FieldWorkDay day = new FieldWorkDay();
        day.setId(UUID.randomUUID()); day.setEmployeeId(employeeId);
        day.setWorkDate(date); day.setNote("ABC"); day.setStatus("PENDING"); day.setVersion(1L);
        when(days.findById(day.getId())).thenReturn(Optional.of(day));
        return day;
    }
    @Test void approvalRecordsReviewerAndNotifiesEmployee() {
        var day = pendingDay(); var reviewer = UUID.randomUUID();
        var result = service.review(day.getId(), reviewer, true, 1L);
        assertEquals("APPROVED", result.status()); assertEquals(reviewer, result.reviewedBy());
        assertNotNull(result.reviewedAt());
        verify(notifications).sendToUser(eq(employeeId), any(), anyString(), anyString(), eq("FIELD_WORK"), eq(day.getId().toString()), eq(true));
    }
    @Test void rejectionDoesNotApproveDay() {
        var day = pendingDay();
        assertEquals("REJECTED", service.review(day.getId(), UUID.randomUUID(), false, 1L).status());
    }
    @Test void selfApprovalIsForbidden() {
        var day = pendingDay();
        assertThrows(BusinessException.class, () -> service.review(day.getId(), employeeId, true, 1L));
        verify(days, never()).save(any());
        verify(days, never()).saveAndFlush(any()); verifyNoInteractions(notifications);
    }
    @Test void cannotReviewStaleOrAlreadyReviewedOrCancelledRequest() {
        var day = pendingDay(); var reviewer = UUID.randomUUID();
        assertThrows(BusinessException.class, () -> service.review(day.getId(), reviewer, true, 0L));
        day.setStatus("APPROVED");
        assertThrows(BusinessException.class, () -> service.review(day.getId(), reviewer, true, 1L));
        day.setStatus("PENDING"); day.setIsDeleted(true);
        assertThrows(BusinessException.class, () -> service.review(day.getId(), reviewer, true, 1L));
        verify(days, never()).save(any());
        verify(days, never()).saveAndFlush(any());
    }
    @Test void editingApprovedDayRequiresNewApprovalAndClearsReview() {
        var day = pendingDay(); day.setStatus("APPROVED"); day.setReviewedBy(UUID.randomUUID()); day.setReviewedAt(Instant.now());
        when(days.findByEmployeeIdAndWorkDate(employeeId, date)).thenReturn(Optional.of(day));
        var result = service.save(employeeId, date, "Updated");
        assertEquals("PENDING", result.status()); assertNull(result.reviewedBy()); assertNull(result.reviewedAt());
        verify(notifications).sendToRoles(anyList(), any(), anyString(), anyString(), eq("FIELD_WORK"), eq(day.getId().toString()), eq(true));
    }
}

