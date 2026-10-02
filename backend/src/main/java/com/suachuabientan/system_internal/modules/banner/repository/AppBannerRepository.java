package com.suachuabientan.system_internal.modules.banner.repository;

import com.suachuabientan.system_internal.modules.banner.entity.AppBanner;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AppBannerRepository extends JpaRepository<AppBanner, UUID> {

    @Query("SELECT b FROM AppBanner b WHERE b.isDeleted = false AND b.isActive = true ORDER BY b.displayOrder ASC, b.createdAt DESC")
    List<AppBanner> findAllActive();

    @Query("SELECT b FROM AppBanner b WHERE b.isDeleted = false ORDER BY b.displayOrder ASC, b.createdAt DESC")
    List<AppBanner> findAllNonDeleted();
}
