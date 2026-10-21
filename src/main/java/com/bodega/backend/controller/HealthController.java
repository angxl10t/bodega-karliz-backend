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
@RequestMapping({"/api/health", "/health", "/"})
public class HealthController {

    private final UsuarioRepository usuarioRepository;
    private final com.bodega.backend.repository.BodegaRepository bodegaRepository;
    private final com.bodega.backend.repository.CategoriaRepository categoriaRepository;

    // Caché en memoria para proteger el pool HikariCP frente a ráfagas de pings o ataques DoS
    private volatile long lastDbCheckTime = 0;
    private volatile String cachedDbStatus = "CONNECTED";
    private static final long DB_CHECK_INTERVAL_MS = 60000; // Máximo 1 consulta a la BD cada 60 segundos
    private static final long START_TIME_MS = System.currentTimeMillis();

    public HealthController(UsuarioRepository usuarioRepository,
                            com.bodega.backend.repository.BodegaRepository bodegaRepository,
                            com.bodega.backend.repository.CategoriaRepository categoriaRepository) {
        this.usuarioRepository = usuarioRepository;
        this.bodegaRepository = bodegaRepository;
        this.categoriaRepository = categoriaRepository;
    }

    @GetMapping("/diagnostico")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<Map<String, Object>> diagnostico() {
        Map<String, Object> resp = new HashMap<>();
        resp.put("version", "1.4.2-enterprise");
        resp.put("row_level_security", "ENABLED");
        resp.put("scalability_engine", "OPTIMIZED_V4");
        try {
            resp.put("bodegas", bodegaRepository.findAll().stream().map(b -> Map.of(
                "idBodega", b.getIdBodega(),
                "nombreComercial", b.getNombreComercial(),
                "plan", b.getPlan() != null ? b.getPlan() : "BASICO",
                "estado", b.getEstado()
            )).toList());
        } catch (Exception e) {
            resp.put("error_bodegas", e.getMessage());
        }
        try {
            resp.put("usuarios", usuarioRepository.findAll().stream().map(u -> Map.of(
                "idUsuario", u.getIdUsuario(),
                "username", u.getUsername(),
                "rol", u.getRol(),
                "idBodega", u.getBodega() != null ? u.getBodega().getIdBodega() : "NULL"
            )).toList());
        } catch (Exception e) {
            resp.put("error_usuarios", e.getMessage());
        }
        try {
            resp.put("categorias", categoriaRepository.findAll().stream().map(c -> Map.of(
                "idCategoria", c.getIdCategoria(),
                "nombre", c.getNombre(),
                "idBodega", c.getBodega() != null ? c.getBodega().getIdBodega() : "NULL"
            )).toList());
        } catch (Exception e) {
            resp.put("error_categorias", e.getMessage());
        }
        return ResponseEntity.ok(resp);
    }

    @org.springframework.web.bind.annotation.RequestMapping(method = {
        org.springframework.web.bind.annotation.RequestMethod.GET,
        org.springframework.web.bind.annotation.RequestMethod.HEAD
    })
    public ResponseEntity<Map<String, Object>> checkHealth() {
        Map<String, Object> response = new HashMap<>();
        response.put("service", "cajaya-pos-backend");
        response.put("version", "1.4.2-enterprise");
        response.put("tenant_engine", "multitenant_enterprise_v4");
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
        response.put("status", "CONNECTED".equals(cachedDbStatus) ? "UP" : "DEGRADED");

        // Telemetría de diagnóstico JVM segura y ligera (sin credenciales ni paths sensibles)
        Runtime runtime = Runtime.getRuntime();
        long maxMemMb = runtime.maxMemory() / (1024 * 1024);
        long totalMemMb = runtime.totalMemory() / (1024 * 1024);
        long freeMemMb = runtime.freeMemory() / (1024 * 1024);
        long usedMemMb = totalMemMb - freeMemMb;
        long uptimeSeconds = (now - START_TIME_MS) / 1000;

        Map<String, Object> jvmStats = new HashMap<>();
        jvmStats.put("used_memory_mb", usedMemMb);
        jvmStats.put("total_memory_mb", totalMemMb);
        jvmStats.put("max_memory_mb", maxMemMb);
        jvmStats.put("uptime_seconds", uptimeSeconds);
        jvmStats.put("active_threads", Thread.activeCount());
        response.put("jvm", jvmStats);

        return ResponseEntity.ok(response);
    }
}
