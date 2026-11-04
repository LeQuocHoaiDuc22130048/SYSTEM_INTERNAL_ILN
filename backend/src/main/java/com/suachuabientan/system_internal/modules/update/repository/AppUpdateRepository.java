package com.suachuabientan.system_internal.modules.update.repository;

import com.suachuabientan.system_internal.modules.update.entity.AppUpdate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AppUpdateRepository extends JpaRepository<AppUpdate, UUID> {
    
    List<AppUpdate> findByIsDeletedFalseOrderByCreatedAtDesc();

    List<AppUpdate> findByPlatformIgnoreCaseAndIsDeletedFalseOrderByCreatedAtDesc(String platform);

    List<AppUpdate> findByChannelIgnoreCaseAndIsDeletedFalseOrderByCreatedAtDesc(String channel);

    List<AppUpdate> findByPlatformIgnoreCaseAndChannelIgnoreCaseAndIsDeletedFalseOrderByCreatedAtDesc(String platform, String channel);

    Optional<AppUpdate> findFirstByVersionAndIsDeletedFalseOrderByCreatedAtDesc(String version);

    Optional<AppUpdate> findFirstByVersionAndPlatformIgnoreCaseAndIsDeletedFalseOrderByCreatedAtDesc(String version, String platform);

    Optional<AppUpdate> findFirstByVersionAndPlatformIgnoreCaseAndChannelIgnoreCaseAndIsDeletedFalseOrderByCreatedAtDesc(String version, String platform, String channel);

    @Query("SELECT a FROM AppUpdate a WHERE a.status = 'RELEASED' AND a.isDeleted = false ORDER BY a.releasedAt DESC, a.createdAt DESC")
    List<AppUpdate> findLatestReleased();

    @Query("SELECT a FROM AppUpdate a WHERE a.status = 'RELEASED' AND a.isDeleted = false AND UPPER(a.platform) = UPPER(:platform) ORDER BY a.releasedAt DESC, a.createdAt DESC")
    List<AppUpdate> findLatestReleasedByPlatform(@Param("platform") String platform);

    @Query("SELECT a FROM AppUpdate a WHERE a.status = 'RELEASED' AND a.isDeleted = false AND UPPER(a.platform) = UPPER(:platform) AND UPPER(a.channel) = UPPER(:channel) ORDER BY a.releasedAt DESC, a.createdAt DESC")
    List<AppUpdate> findLatestReleasedByPlatformAndChannel(@Param("platform") String platform, @Param("channel") String channel);
}
