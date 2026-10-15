package com.bodega.backend.security;

import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Servicio de Mitigación de Fuerza Bruta y Protección de Pool HikariCP.
 * Bloquea temporalmente solicitudes tras 5 intentos fallidos por IP o usuario,
 * respondiendo antes de consultar la base de datos para prevenir saturación de conexiones.
 */
@Service
public class LoginRateLimiterService {

    private static final int MAX_FAILED_ATTEMPTS = 5;
    private static final long BLOCK_DURATION_SECONDS = 300; // 5 minutos de bloqueo

    private static class AttemptRecord {
        int failedAttempts;
        Instant lastAttemptTime;
        Instant blockedUntil;

        AttemptRecord(Instant attemptTime) {
            this.failedAttempts = 1;
            this.lastAttemptTime = attemptTime;
        }
    }

    private final ConcurrentHashMap<String, AttemptRecord> ipAttempts = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, AttemptRecord> userIpAttempts = new ConcurrentHashMap<>();

    private String getCompositeKey(String ip, String username) {
        String cleanIp = (ip != null && !ip.isBlank()) ? ip.trim() : "unknown_ip";
        String cleanUser = (username != null && !username.isBlank()) ? username.trim().toLowerCase() : "unknown_user";
        return cleanIp + "#" + cleanUser;
    }

    /**
     * Verifica si una IP o usuario se encuentra actualmente bloqueado.
     * La verificación por usuario está acotada a la IP origen para prevenir ataques de
     * Denegación de Servicio por Bloqueo de Cuentas (Account Lockout DoS).
     */
    public boolean isBlocked(String ip, String username) {
        Instant now = Instant.now();
        return isKeyBlocked(ipAttempts, ip, now) || isKeyBlocked(userIpAttempts, getCompositeKey(ip, username), now);
    }

    private boolean isKeyBlocked(ConcurrentHashMap<String, AttemptRecord> map, String key, Instant now) {
        if (key == null || key.isBlank()) return false;
        AttemptRecord record = map.get(key);
        if (record == null) return false;

        if (record.blockedUntil != null && now.isBefore(record.blockedUntil)) {
            return true;
        }
        if (record.blockedUntil != null && now.isAfter(record.blockedUntil)) {
            // Desbloqueo automático al expirar la ventana de penalización
            map.remove(key);
        }
        return false;
    }

    /**
     * Retorna los minutos restantes de penalización.
     */
    public long getRemainingBlockMinutes(String ip, String username) {
        Instant now = Instant.now();
        Instant untilIp = getBlockedUntil(ipAttempts, ip);
        Instant untilUser = getBlockedUntil(userIpAttempts, getCompositeKey(ip, username));

        Instant maxUntil = null;
        if (untilIp != null && untilUser != null) {
            maxUntil = untilIp.isAfter(untilUser) ? untilIp : untilUser;
        } else if (untilIp != null) {
            maxUntil = untilIp;
        } else {
            maxUntil = untilUser;
        }

        if (maxUntil != null && now.isBefore(maxUntil)) {
            long seconds = java.time.Duration.between(now, maxUntil).getSeconds();
            return Math.max(1, (seconds + 59) / 60);
        }
        return 0;
    }

    private Instant getBlockedUntil(ConcurrentHashMap<String, AttemptRecord> map, String key) {
        if (key == null || key.isBlank()) return null;
        AttemptRecord record = map.get(key);
        return record != null ? record.blockedUntil : null;
    }

    /**
     * Registra un intento fallido para la IP y para la combinación IP + usuario.
     */
    public void registerFailedAttempt(String ip, String username) {
        Instant now = Instant.now();
        recordFailedAttempt(ipAttempts, ip, now);
        recordFailedAttempt(userIpAttempts, getCompositeKey(ip, username), now);
    }

    private void recordFailedAttempt(ConcurrentHashMap<String, AttemptRecord> map, String key, Instant now) {
        if (key == null || key.isBlank()) return;

        map.compute(key, (k, record) -> {
            if (record == null) {
                return new AttemptRecord(now);
            }

            // Si el último intento fue hace más de 5 minutos, reiniciar contador
            if (java.time.Duration.between(record.lastAttemptTime, now).getSeconds() > BLOCK_DURATION_SECONDS) {
                record.failedAttempts = 1;
                record.blockedUntil = null;
            } else {
                record.failedAttempts++;
                if (record.failedAttempts >= MAX_FAILED_ATTEMPTS) {
                    record.blockedUntil = now.plusSeconds(BLOCK_DURATION_SECONDS);
                }
            }
            record.lastAttemptTime = now;
            return record;
        });
    }

    /**
     * Limpia los contadores al producirse una autenticación exitosa.
     */
    public void resetAttempts(String ip, String username) {
        if (ip != null && !ip.isBlank()) {
            ipAttempts.remove(ip);
        }
        if (username != null && !username.isBlank()) {
            userIpAttempts.remove(getCompositeKey(ip, username));
        }
    }
}
