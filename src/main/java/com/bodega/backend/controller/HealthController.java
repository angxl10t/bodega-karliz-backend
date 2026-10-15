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

    public HealthController(UsuarioRepository usuarioRepository) {
        this.usuarioRepository = usuarioRepository;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> checkHealth() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "bodega-karliz-backend");
        response.put("timestamp", Instant.now().toString());

        try {
            // Consulta ultraligera para mantener activa la conexión a PostgreSQL y evitar pausas de inactividad
            usuarioRepository.count();
            response.put("database", "CONNECTED");
        } catch (Exception e) {
            response.put("database", "DEGRADED");
        }

        return ResponseEntity.ok(response);
    }
}
