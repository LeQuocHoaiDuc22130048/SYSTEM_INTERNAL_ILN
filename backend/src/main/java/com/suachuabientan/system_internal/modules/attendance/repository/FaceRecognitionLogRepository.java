package com.suachuabientan.system_internal.modules.attendance.repository;

import com.suachuabientan.system_internal.modules.attendance.entity.FaceRecognitionLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

public interface FaceRecognitionLogRepository extends JpaRepository<FaceRecognitionLog, UUID> {
    Optional<FaceRecognitionLog> findByLocalAttemptIdAndSourceAndIsDeletedFalse(String localAttemptId, String source);

    @Query("""
            SELECT COUNT(l) FROM FaceRecognitionLog l
            WHERE l.occurredAt >= :from
              AND l.occurredAt < :to
              AND l.isDeleted = false
              AND l.employeeId IS NOT NULL
            """)
    long countAttemptsWithCandidate(@Param("from") Instant from, @Param("to") Instant to);

    @Query("""
            SELECT COUNT(l) FROM FaceRecognitionLog l
            WHERE l.occurredAt >= :from
              AND l.occurredAt < :to
              AND l.isDeleted = false
              AND l.employeeId IS NOT NULL
              AND l.outcome = 'REJECTED'
            """)
    long countRejectedWithCandidate(@Param("from") Instant from, @Param("to") Instant to);
}
