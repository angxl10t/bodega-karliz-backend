package com.bodega.backend.security;

import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

public class JwtUtilTest {

    private static final String CUSTOM_STRONG_SECRET = "9F8B7C6D5E4A3F2E1D0C9B8A7F6E5D4C3B2A1908F7E6D5C4B3A29180F7E6D5C4";

    @Test
    void validateSecret_rechazaClaveVaciaOCorta() {
        JwtUtil jwtUtil = new JwtUtil();
        ReflectionTestUtils.setField(jwtUtil, "secretKey", "corto");
        ReflectionTestUtils.setField(jwtUtil, "activeProfile", "default");

        IllegalStateException ex = assertThrows(IllegalStateException.class, jwtUtil::validateSecret);
        assertTrue(ex.getMessage().contains("JWT_SECRET"));
    }

    @Test
    void validateSecret_rechazaDefaultDevSecretEnProduccion() {
        JwtUtil jwtUtil = new JwtUtil();
        ReflectionTestUtils.setField(jwtUtil, "secretKey", JwtUtil.DEFAULT_DEV_SECRET);
        ReflectionTestUtils.setField(jwtUtil, "activeProfile", "prod");

        IllegalStateException ex = assertThrows(IllegalStateException.class, jwtUtil::validateSecret);
        assertTrue(ex.getMessage().contains("entorno de producción"));
    }

    @Test
    void validateSecret_aceptaDefaultDevSecretSoloEnDesarrolloLocal() {
        JwtUtil jwtUtil = new JwtUtil();
        ReflectionTestUtils.setField(jwtUtil, "secretKey", JwtUtil.DEFAULT_DEV_SECRET);
        ReflectionTestUtils.setField(jwtUtil, "activeProfile", "default");

        // En entornos locales sin perfil prod ni variables Render/ENVIRONMENT, no debe abortar
        if (!EnvironmentSecurityHelper.isProduction("default")) {
            assertDoesNotThrow(jwtUtil::validateSecret);
        }
    }

    @Test
    void validateSecret_aceptaClaveFuerteEnProduccionYGeneraTokenValido() {
        JwtUtil jwtUtil = new JwtUtil();
        ReflectionTestUtils.setField(jwtUtil, "secretKey", CUSTOM_STRONG_SECRET);
        ReflectionTestUtils.setField(jwtUtil, "activeProfile", "prod");
        ReflectionTestUtils.setField(jwtUtil, "expirationMs", 3600_000L);

        assertDoesNotThrow(jwtUtil::validateSecret);

        String token = jwtUtil.generateToken("bodega_test", "ADMIN", 7L, "PRO");
        assertNotNull(token);
        assertEquals("bodega_test", jwtUtil.extractUsername(token));
        assertTrue(jwtUtil.validateToken(token, "bodega_test"));
    }
}
