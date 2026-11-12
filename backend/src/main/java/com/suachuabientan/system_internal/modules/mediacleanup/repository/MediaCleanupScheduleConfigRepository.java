package com.suachuabientan.system_internal.modules.mediacleanup.repository;

import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaCleanupScheduleConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface MediaCleanupScheduleConfigRepository extends JpaRepository<MediaCleanupScheduleConfig, Integer> {
}

