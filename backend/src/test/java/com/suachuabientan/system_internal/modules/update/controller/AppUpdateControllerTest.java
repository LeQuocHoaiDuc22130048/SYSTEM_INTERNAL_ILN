package com.suachuabientan.system_internal.modules.update.controller;

import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import com.suachuabientan.system_internal.modules.update.entity.AppUpdate;
import com.suachuabientan.system_internal.modules.update.repository.AppUpdateRepository;
import com.suachuabientan.system_internal.modules.update.service.AppUpdateService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.file.Path;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AppUpdateControllerTest {

    private AppUpdateController controller;
    private AppUpdateService service;
    private AppUpdateRepository repository;
    private UserRepository userRepository;
    private NotificationService notificationService;

    @TempDir
    Path tempReleaseDir;

    @BeforeEach
    void setUp() {
        repository = mock(AppUpdateRepository.class);
        userRepository = mock(UserRepository.class);
        notificationService = mock(NotificationService.class);
        service = new AppUpdateService(repository, userRepository, notificationService);
        ReflectionTestUtils.setField(service, "releaseDir", tempReleaseDir.toString());
        controller = new AppUpdateController(service);
    }

    @Test
    void testIsVersionNewer_WhenLatestIsNewer_ReturnsTrue() {
        assertTrue(controller.isVersionNewer("1.1.4", "1.1.3"));
        assertTrue(controller.isVersionNewer("1.2.0", "1.1.9"));
        assertTrue(controller.isVersionNewer("2.0.0", "1.9.9"));
        assertTrue(controller.isVersionNewer("1.1.10", "1.1.4"));
    }

    @Test
    void testIsVersionNewer_WithBuildMetadata_StripsBuildNumberAndComparesCorrectly() {
        assertTrue(controller.isVersionNewer("1.1.4", "1.1.3+8"));
        assertFalse(controller.isVersionNewer("1.1.4", "1.1.4+8"));
        assertTrue(controller.isVersionNewer("1.1.5+10", "1.1.4+8"));
    }

    @Test
    void testIsVersionNewer_WhenVersionsEqual_ReturnsFalse() {
        assertFalse(controller.isVersionNewer("1.1.4", "1.1.4"));
        assertFalse(controller.isVersionNewer("1.0.0", "1.0.0"));
    }

    @Test
    void testIsVersionNewer_WhenLatestIsOlder_ReturnsFalse() {
        assertFalse(controller.isVersionNewer("1.1.3", "1.1.4"));
        assertFalse(controller.isVersionNewer("1.0.9", "1.1.0"));
    }

    @Test
    void testIsVersionNewer_NullOrInvalid_ReturnsFalse() {
        assertFalse(controller.isVersionNewer(null, "1.1.0"));
        assertFalse(controller.isVersionNewer("1.1.0", null));
        assertFalse(controller.isVersionNewer("", "1.1.0"));
    }

    @Test
    void testIsMandatory_WithMinSupportedVersion() {
        AppUpdate update = AppUpdate.builder()
                .version("1.2.0")
                .mandatory(false)
                .minSupportedVersion("1.1.5")
                .build();

        // Client 1.1.0 < minSupportedVersion 1.1.5 => mandatory = true
        assertTrue(service.isMandatory(update, "1.1.0"));
        // Client 1.1.4 < minSupportedVersion 1.1.5 => mandatory = true
        assertTrue(service.isMandatory(update, "1.1.4"));
        // Client 1.1.5 == minSupportedVersion 1.1.5 => mandatory = false
        assertFalse(service.isMandatory(update, "1.1.5"));
        // Client 1.1.8 > minSupportedVersion 1.1.5 => mandatory = false
        assertFalse(service.isMandatory(update, "1.1.8"));
    }

    @Test
    void testRollbackUpdate_ChangesStatusToRolledBack() {
        UUID updateId = UUID.randomUUID();
        AppUpdate update = AppUpdate.builder()
                .version("1.2.0")
                .status("RELEASED")
                .platform("ANDROID")
                .build();
        update.setId(updateId);

        when(repository.findById(updateId)).thenReturn(Optional.of(update));
        when(repository.save(any(AppUpdate.class))).thenAnswer(invocation -> invocation.getArgument(0));

        AppUpdate rolledBack = service.rollbackUpdate(updateId);
        assertEquals("ROLLED_BACK", rolledBack.getStatus());
        verify(repository).save(update);
    }

    @Test
    void testCreateUpdate_ValidateFileExtension_RejectsMismatchedFiles() {
        MockMultipartFile apkFile =
            new MockMultipartFile("file", "test.apk", "application/vnd.android.package-archive", "dummy".getBytes());
        MockMultipartFile ipaFile =
            new MockMultipartFile("file", "test.ipa", "application/octet-stream", "dummy".getBytes());

        // iOS rejects .apk
        IllegalArgumentException iosEx = assertThrows(IllegalArgumentException.class, () -> {
            service.createUpdate(apkFile, "IOS", "1.2.0", "notes", null, false, "DRAFT");
        });
        assertTrue(iosEx.getMessage().contains(".ipa"));

        // Android rejects .ipa
        IllegalArgumentException androidEx = assertThrows(IllegalArgumentException.class, () -> {
            service.createUpdate(ipaFile, "ANDROID", "1.2.0", "notes", null, false, "DRAFT");
        });
        assertTrue(androidEx.getMessage().contains(".apk"));
    }

    @Test
    void testCreateUpdate_IsolatesFilenamesByChannelAndPreservesSha256WhenUpdatingMetadata() {
        when(repository.save(any(AppUpdate.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(repository.findFirstByVersionAndPlatformIgnoreCaseAndChannelIgnoreCaseAndIsDeletedFalseOrderByCreatedAtDesc(
                anyString(), anyString(), anyString())).thenReturn(Optional.empty());

        MockMultipartFile prodFile =
            new MockMultipartFile("file", "prod.apk", "application/vnd.android.package-archive", "prod-content".getBytes());
        MockMultipartFile betaFile =
            new MockMultipartFile("file", "beta.apk", "application/vnd.android.package-archive", "beta-content-different".getBytes());

        AppUpdate prodUpdate = service.createUpdate(
                prodFile, "ANDROID", "1.2.0", "Prod notes", null, false, "DRAFT", "1.1.0", "PRODUCTION", null, null);
        AppUpdate betaUpdate = service.createUpdate(
                betaFile, "ANDROID", "1.2.0", "Beta notes", null, false, "RELEASED", "1.1.0", "BETA", null, null);

        assertEquals("/api/v1/app-updates/download/system_internal_v1.2.0.apk", prodUpdate.getDownloadUrl());
        assertEquals("/api/v1/app-updates/download/system_internal_v1.2.0_beta.apk", betaUpdate.getDownloadUrl());
        assertNotNull(prodUpdate.getSha256());
        assertNotNull(betaUpdate.getSha256());
        assertNotEquals(prodUpdate.getSha256(), betaUpdate.getSha256());

        // Releasing BETA channel should NOT spam mass notifications to all users
        verifyNoInteractions(userRepository);
        verifyNoInteractions(notificationService);

        // Updating metadata of prodUpdate without re-uploading file preserves SHA-256 and fileSize
        when(repository.findFirstByVersionAndPlatformIgnoreCaseAndChannelIgnoreCaseAndIsDeletedFalseOrderByCreatedAtDesc(
                "1.2.0", "ANDROID", "PRODUCTION")).thenReturn(Optional.of(prodUpdate));
        String originalSha = prodUpdate.getSha256();
        Long originalSize = prodUpdate.getFileSize();

        AppUpdate updatedMeta = service.createUpdate(
                null, "ANDROID", "1.2.0", "Updated prod notes", prodUpdate.getDownloadUrl(), true, "DRAFT", "1.1.5", "PRODUCTION", null, null);
        assertEquals(originalSha, updatedMeta.getSha256());
        assertEquals(originalSize, updatedMeta.getFileSize());
        assertEquals("1.1.5", updatedMeta.getMinSupportedVersion());
    }
}
