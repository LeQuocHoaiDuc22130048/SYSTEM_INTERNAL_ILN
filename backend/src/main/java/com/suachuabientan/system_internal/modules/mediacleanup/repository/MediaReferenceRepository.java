package com.suachuabientan.system_internal.modules.mediacleanup.repository;

import com.suachuabientan.system_internal.modules.mediacleanup.entity.MediaReference;
import com.suachuabientan.system_internal.modules.mediacleanup.enums.MediaReferenceType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MediaReferenceRepository extends JpaRepository<MediaReference, UUID> {

    boolean existsByMediaIdAndActiveTrue(UUID mediaId);

    List<MediaReference> findByReferenceTypeAndReferenceIdAndActiveTrue(
            MediaReferenceType referenceType,
            String referenceId
    );

    Optional<MediaReference> findByMediaIdAndReferenceTypeAndReferenceId(
            UUID mediaId,
            MediaReferenceType referenceType,
            String referenceId
    );

    List<MediaReference> findByMediaIdAndActiveTrue(UUID mediaId);
}

