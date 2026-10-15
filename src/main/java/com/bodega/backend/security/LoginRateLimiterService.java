package com.bodega.backend.security;

import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
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

    private static final int MAX_GLOBAL_USER_FAILED_ATTEMPTS = 15;

    private final ConcurrentHashMap<String, AttemptRecord> ipAttempts = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, AttemptRecord> userIpAttempts = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, AttemptRecord> globalUserAttempts = new ConcurrentHashMap<>();

    private String getCompositeKey(String ip, String username) {
        String cleanIp = (ip != null && !ip.isBlank()) ? ip.trim() : "unknown_ip";
        String cleanUser = (username != null && !username.isBlank()) ? username.trim().toLowerCase() : "unknown_user";
        return cleanIp + "#" + cleanUser;
    }

    /**
     * Verifica si una IP o usuario se encuentra actualmente bloqueado.
     * Evalúa IP de origen, combinación IP + Usuario, y umbral global contra ataques distribuidos.
     */
    public boolean isBlocked(String ip, String username) {
        Instant now = Instant.now();
        String cleanUser = (username != null && !username.isBlank()) ? username.trim().toLowerCase() : "";
        return isKeyBlocked(ipAttempts, ip, now) 
            || isKeyBlocked(userIpAttempts, getCompositeKey(ip, username), now)
            || (!cleanUser.isEmpty() && isKeyBlocked(globalUserAttempts, cleanUser, now));
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
        String cleanUser = (username != null && !username.isBlank()) ? username.trim().toLowerCase() : "";
        Instant untilGlobalUser = !cleanUser.isEmpty() ? getBlockedUntil(globalUserAttempts, cleanUser) : null;

        Instant maxUntil = null;
        if (untilIp != null) {
            maxUntil = untilIp;
        }
        if (untilUser != null && (maxUntil == null || untilUser.isAfter(maxUntil))) {
            maxUntil = untilUser;
        }
        if (untilGlobalUser != null && (maxUntil == null || untilGlobalUser.isAfter(maxUntil))) {
            maxUntil = untilGlobalUser;
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
     * Registra un intento fallido para la IP, la combinación IP + usuario y el contador global de usuario.
     * Aplica tarpit (retraso progresivo) para estrangular bots de fuerza bruta.
     */
    public void registerFailedAttempt(String ip, String username) {
        Instant now = Instant.now();
        recordFailedAttempt(ipAttempts, ip, now, MAX_FAILED_ATTEMPTS);
        recordFailedAttempt(userIpAttempts, getCompositeKey(ip, username), now, MAX_FAILED_ATTEMPTS);

        String cleanUser = (username != null && !username.isBlank()) ? username.trim().toLowerCase() : "";
        if (!cleanUser.isEmpty()) {
            recordFailedAttempt(globalUserAttempts, cleanUser, now, MAX_GLOBAL_USER_FAILED_ATTEMPTS);
        }

        // Tarpit defensivo: retardo progresivo (350ms * intentos) para desarmar automatizaciones masivas
        AttemptRecord rec = userIpAttempts.get(getCompositeKey(ip, username));
        if (rec != null && rec.failedAttempts > 1) {
            try {
                long delayMs = Math.min((long) rec.failedAttempts * 350L, 2000L);
                Thread.sleep(delayMs);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }

    private void recordFailedAttempt(ConcurrentHashMap<String, AttemptRecord> map, String key, Instant now, int maxAttempts) {
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
                if (record.failedAttempts >= maxAttempts) {
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
            globalUserAttempts.remove(username.trim().toLowerCase());
        }
    }

    /**
     * Tarea programada: Purga periódica cada 5 minutos para prevenir fugas de memoria (unbounded growth).
     */
    @org.springframework.scheduling.annotation.Scheduled(fixedRate = 300000)
    public void limpiarRegistrosExpirados() {
        Instant now = Instant.now();
        java.util.function.Predicate<AttemptRecord> isExpired = r ->
            (r.blockedUntil != null && now.isAfter(r.blockedUntil))
            || (r.blockedUntil == null && java.time.Duration.between(r.lastAttemptTime, now).getSeconds() > BLOCK_DURATION_SECONDS);

        ipAttempts.entrySet().removeIf(entry -> isExpired.test(entry.getValue()));
        userIpAttempts.entrySet().removeIf(entry -> isExpired.test(entry.getValue()));
        globalUserAttempts.entrySet().removeIf(entry -> isExpired.test(entry.getValue()));
    }
}
