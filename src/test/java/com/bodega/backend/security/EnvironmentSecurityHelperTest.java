package com.bodega.backend.security;

import org.junit.jupiter.api.Test;

import java.util.Collections;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

public class EnvironmentSecurityHelperTest {

    @Test
    void detectsProductionBySpringProfileIncludingMultiProfileList() {
        assertTrue(EnvironmentSecurityHelper.isProduction("prod", Collections.emptyMap()));
        assertTrue(EnvironmentSecurityHelper.isProduction("production", Collections.emptyMap()));
        assertTrue(EnvironmentSecurityHelper.isProduction("postgres, prod", Collections.emptyMap()));
        assertFalse(EnvironmentSecurityHelper.isProduction("default", Collections.emptyMap()));
        assertFalse(EnvironmentSecurityHelper.isProduction("dev,local", Collections.emptyMap()));
    }

    @Test
    void detectsProductionByRenderAndEnvironmentVariables() {
        assertTrue(EnvironmentSecurityHelper.isProduction("default", Map.of("RENDER", "true")));
        assertTrue(EnvironmentSecurityHelper.isProduction("default", Map.of("RENDER_SERVICE_ID", "srv-12345")));
        assertTrue(EnvironmentSecurityHelper.isProduction("default", Map.of("ENVIRONMENT", "production")));
        assertTrue(EnvironmentSecurityHelper.isProduction("default", Map.of("ENVIRONMENT", "prod")));
        assertFalse(EnvironmentSecurityHelper.isProduction("default", Map.of("RENDER", "false", "ENVIRONMENT", "staging")));
    }
}
