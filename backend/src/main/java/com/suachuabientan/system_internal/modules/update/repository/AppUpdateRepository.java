package com.suachuabientan.system_internal.modules.update.repository;

import com.suachuabientan.system_internal.modules.update.entity.AppUpdate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AppUpdateRepository extends JpaRepository<AppUpdate, UUID> {
    
    List<AppUpdate> findByIsDeletedFalseOrderByCreatedAtDesc();

    java.util.Optional<AppUpdate> findByVersionAndIsDeletedFalse(String version);

    @Query("SELECT a FROM AppUpdate a WHERE a.status = 'RELEASED' AND a.isDeleted = false ORDER BY a.releasedAt DESC, a.createdAt DESC")
    List<AppUpdate> findLatestReleased();
}
