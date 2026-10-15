package com.bodega.backend.controller;

import com.bodega.backend.repository.UsuarioRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping({"/api/health", "/health"})
public class HealthController {

    private final UsuarioRepository usuarioRepository;

    // Caché en memoria para proteger el pool HikariCP frente a ráfagas de pings o ataques DoS
    private volatile long lastDbCheckTime = 0;
    private volatile String cachedDbStatus = "CONNECTED";
    private static final long DB_CHECK_INTERVAL_MS = 60000; // Máximo 1 consulta a la BD cada 60 segundos

    public HealthController(UsuarioRepository usuarioRepository) {
        this.usuarioRepository = usuarioRepository;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> checkHealth() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "bodega-karliz-backend");
        response.put("timestamp", Instant.now().toString());

        long now = System.currentTimeMillis();
        if (now - lastDbCheckTime > DB_CHECK_INTERVAL_MS) {
            synchronized (this) {
                if (now - lastDbCheckTime > DB_CHECK_INTERVAL_MS) {
                    try {
                        // Consulta ultraligera de verificación y keep-alive de conexión
                        usuarioRepository.count();
                        cachedDbStatus = "CONNECTED";
                    } catch (Exception e) {
                        cachedDbStatus = "DEGRADED";
                    }
                    lastDbCheckTime = System.currentTimeMillis();
                }
            }
        }

        response.put("database", cachedDbStatus);
        return ResponseEntity.ok(response);
    }
}
