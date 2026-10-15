package com.bodega.backend.security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

public class LoginRateLimiterServiceTest {

    private LoginRateLimiterService rateLimiter;

    @BeforeEach
    void setUp() {
        rateLimiter = new LoginRateLimiterService();
    }

    @Test
    void testRateLimiter_BloqueaTras5IntentosMismaIp() {
        String ip = "192.168.1.100";
        String user = "cajero1";

        assertFalse(rateLimiter.isBlocked(ip, user));

        for (int i = 0; i < 4; i++) {
            rateLimiter.registerFailedAttempt(ip, user);
            assertFalse(rateLimiter.isBlocked(ip, user), "No debe bloquear antes del 5to intento");
        }

        // 5to intento fallido
        rateLimiter.registerFailedAttempt(ip, user);
        assertTrue(rateLimiter.isBlocked(ip, user), "Debe bloquear tras alcanzar 5 intentos");
        assertTrue(rateLimiter.getRemainingBlockMinutes(ip, user) > 0);
    }

    @Test
    void testRateLimiter_ResetExitoso() {
        String ip = "10.0.0.5";
        String user = "admin";

        for (int i = 0; i < 4; i++) {
            rateLimiter.registerFailedAttempt(ip, user);
        }

        // Login exitoso
        rateLimiter.resetAttempts(ip, user);
        assertFalse(rateLimiter.isBlocked(ip, user));

        // Intento fallido después de reset debe contar como 1
        rateLimiter.registerFailedAttempt(ip, user);
        assertFalse(rateLimiter.isBlocked(ip, user));
    }

    @Test
    void testRateLimiter_ProteccionContraAtaquesDistribuidos() {
        String targetUser = "admin";

        // Simular ataque distribuido desde múltiples IPs diferentes hacia la misma cuenta
        for (int i = 1; i <= 14; i++) {
            rateLimiter.registerFailedAttempt("10.0.1." + i, targetUser);
        }
        assertFalse(rateLimiter.isBlocked("10.0.2.1", targetUser));

        // Intento 15 global hacia el mismo usuario
        rateLimiter.registerFailedAttempt("10.0.1.15", targetUser);
        assertTrue(rateLimiter.isBlocked("10.0.2.99", targetUser), 
                "Debe bloquear temporalmente el usuario tras 15 intentos fallidos distribuidos");
    }
}
