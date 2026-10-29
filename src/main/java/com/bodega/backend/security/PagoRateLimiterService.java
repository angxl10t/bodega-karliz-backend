package com.bodega.backend.security;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Servicio de Mitigación de Ataques de Fuerza Bruta para Códigos de Operación Bancarios (Yape/Plin).
 * Bloquea temporalmente intentos repetitivos tras 4 fallos consecutivos por Bodega o IP,
 * evitando enumeración masiva o adivinación de códigos de 6 a 8 dígitos.
 */
@Service
public class PagoRateLimiterService {

    private static final int MAX_FAILED_ATTEMPTS = 4;
    private static final long BLOCK_DURATION_SECONDS = 900; // 15 minutos de penalización

    private static class AttemptRecord {
        int failedAttempts;
        Instant lastAttemptTime;
        Instant blockedUntil;

        AttemptRecord(Instant attemptTime) {
            this.failedAttempts = 1;
            this.lastAttemptTime = attemptTime;
        }
    }

    private final ConcurrentHashMap<String, AttemptRecord> bodegaAttempts = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, AttemptRecord> ipAttempts = new ConcurrentHashMap<>();

    public boolean isBlocked(String ip, Long idBodega) {
        Instant now = Instant.now();
        String bodegaKey = idBodega != null ? "BOD_" + idBodega : "";
        return isKeyBlocked(ipAttempts, ip, now) || (!bodegaKey.isEmpty() && isKeyBlocked(bodegaAttempts, bodegaKey, now));
    }

    private boolean isKeyBlocked(ConcurrentHashMap<String, AttemptRecord> map, String key, Instant now) {
        if (key == null || key.isBlank()) return false;
        AttemptRecord record = map.get(key);
        if (record == null) return false;

        if (record.blockedUntil != null && now.isBefore(record.blockedUntil)) {
            return true;
        }
        if (record.blockedUntil != null && now.isAfter(record.blockedUntil)) {
            map.remove(key);
        }
        return false;
    }

    public long getRemainingBlockMinutes(String ip, Long idBodega) {
        Instant now = Instant.now();
        Instant untilIp = getBlockedUntil(ipAttempts, ip);
        String bodegaKey = idBodega != null ? "BOD_" + idBodega : "";
        Instant untilBodega = !bodegaKey.isEmpty() ? getBlockedUntil(bodegaAttempts, bodegaKey) : null;

        Instant maxUntil = null;
        if (untilIp != null) maxUntil = untilIp;
        if (untilBodega != null && (maxUntil == null || untilBodega.isAfter(maxUntil))) {
            maxUntil = untilBodega;
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

    public void registerFailedAttempt(String ip, Long idBodega) {
        Instant now = Instant.now();
        recordFailedAttempt(ipAttempts, ip, now);
        if (idBodega != null) {
            recordFailedAttempt(bodegaAttempts, "BOD_" + idBodega, now);
        }
    }

    private void recordFailedAttempt(ConcurrentHashMap<String, AttemptRecord> map, String key, Instant now) {
        if (key == null || key.isBlank()) return;

        map.compute(key, (k, record) -> {
            if (record == null) {
                return new AttemptRecord(now);
            }
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

    public void resetAttempts(String ip, Long idBodega) {
        if (ip != null && !ip.isBlank()) {
            ipAttempts.remove(ip);
        }
        if (idBodega != null) {
            bodegaAttempts.remove("BOD_" + idBodega);
        }
    }

    @Scheduled(fixedRate = 600000) // Cada 10 minutos
    public void limpiarRegistrosExpirados() {
        Instant now = Instant.now();
        java.util.function.Predicate<AttemptRecord> isExpired = r ->
            (r.blockedUntil != null && now.isAfter(r.blockedUntil))
            || (r.blockedUntil == null && java.time.Duration.between(r.lastAttemptTime, now).getSeconds() > BLOCK_DURATION_SECONDS);

        ipAttempts.entrySet().removeIf(entry -> isExpired.test(entry.getValue()));
        bodegaAttempts.entrySet().removeIf(entry -> isExpired.test(entry.getValue()));
    }
}
