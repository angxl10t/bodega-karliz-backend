package com.bodega.backend.security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

public class PagoRateLimiterServiceTest {

    private PagoRateLimiterService limiter;

    @BeforeEach
    void setUp() {
        limiter = new PagoRateLimiterService();
    }

    @Test
    @DisplayName("Inicialmente la IP y bodega no deben estar bloqueadas")
    void testInicialmenteDesbloqueado() {
        assertFalse(limiter.isBlocked("192.168.1.100", 1L));
        assertEquals(0, limiter.getRemainingBlockMinutes("192.168.1.100", 1L));
    }

    @Test
    @DisplayName("Tras 4 intentos fallidos consecutivos, debe bloquear y calcular tiempo restante")
    void testBloqueoTrasCuatroFallos() {
        String ip = "10.0.0.5";
        Long idBodega = 42L;

        limiter.registerFailedAttempt(ip, idBodega);
        assertFalse(limiter.isBlocked(ip, idBodega));

        limiter.registerFailedAttempt(ip, idBodega);
        assertFalse(limiter.isBlocked(ip, idBodega));

        limiter.registerFailedAttempt(ip, idBodega);
        assertFalse(limiter.isBlocked(ip, idBodega));

        // 4to intento: Umbral alcanzado
        limiter.registerFailedAttempt(ip, idBodega);
        assertTrue(limiter.isBlocked(ip, idBodega));
        assertTrue(limiter.getRemainingBlockMinutes(ip, idBodega) > 0);
    }

    @Test
    @DisplayName("resetAttempts debe limpiar penalizaciones al validar exitosamente un pago")
    void testResetAttemptsLimpiaPenalizaciones() {
        String ip = "10.0.0.9";
        Long idBodega = 99L;

        // 4 intentos fallidos
        for (int i = 0; i < 4; i++) {
            limiter.registerFailedAttempt(ip, idBodega);
        }
        assertTrue(limiter.isBlocked(ip, idBodega));

        // Reset
        limiter.resetAttempts(ip, idBodega);
        assertFalse(limiter.isBlocked(ip, idBodega));
        assertEquals(0, limiter.getRemainingBlockMinutes(ip, idBodega));
    }
}
