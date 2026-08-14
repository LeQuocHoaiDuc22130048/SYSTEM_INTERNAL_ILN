package com.suachuabientan.system_internal.modules.attendance.repository;

import com.suachuabientan.system_internal.modules.attendance.entity.FaceRecognitionDailyAlert;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

public interface FaceRecognitionDailyAlertRepository extends JpaRepository<FaceRecognitionDailyAlert, UUID> {
    Optional<FaceRecognitionDailyAlert> findByMetricDateAndIsDeletedFalse(LocalDate metricDate);
}
