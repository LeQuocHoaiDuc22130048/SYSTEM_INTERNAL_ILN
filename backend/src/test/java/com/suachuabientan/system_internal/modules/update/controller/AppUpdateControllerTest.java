package com.suachuabientan.system_internal.modules.update.controller;

import com.suachuabientan.system_internal.modules.update.service.AppUpdateService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class AppUpdateControllerTest {

    private AppUpdateController controller;

    @BeforeEach
    void setUp() {
        AppUpdateService service = new AppUpdateService(null, null, null);
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
        // 1.1.4 > 1.1.3+8 (previously treated 1.1.3+8 as 1.1.38 which caused false)
        assertTrue(controller.isVersionNewer("1.1.4", "1.1.3+8"));
        
        // 1.1.4 is NOT newer than 1.1.4+8 (same base version)
        assertFalse(controller.isVersionNewer("1.1.4", "1.1.4+8"));

        // 1.1.5+10 > 1.1.4+8
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
}
