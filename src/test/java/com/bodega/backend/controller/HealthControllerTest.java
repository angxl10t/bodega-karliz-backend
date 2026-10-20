package com.bodega.backend.controller;

import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.UsuarioRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class HealthControllerTest {

    @Mock
    private UsuarioRepository usuarioRepository;

    @Mock
    private BodegaRepository bodegaRepository;

    @Mock
    private CategoriaRepository categoriaRepository;

    @InjectMocks
    private HealthController healthController;

    @Test
    void testCheckHealth_WhenDbConnected_ReturnsUpAndJvmTelemetry() {
        when(usuarioRepository.count()).thenReturn(5L);

        ResponseEntity<Map<String, Object>> response = healthController.checkHealth();

        assertNotNull(response);
        assertEquals(200, response.getStatusCode().value());
        Map<String, Object> body = response.getBody();
        assertNotNull(body);

        assertEquals("UP", body.get("status"));
        assertEquals("cajaya-pos-backend", body.get("service"));
        assertEquals("1.4.2-enterprise", body.get("version"));
        assertEquals("CONNECTED", body.get("database"));
        assertNotNull(body.get("timestamp"));

        @SuppressWarnings("unchecked")
        Map<String, Object> jvm = (Map<String, Object>) body.get("jvm");
        assertNotNull(jvm);
        assertTrue((Long) jvm.get("max_memory_mb") > 0);
        assertTrue((Long) jvm.get("total_memory_mb") > 0);
        assertNotNull(jvm.get("uptime_seconds"));
        assertNotNull(jvm.get("active_threads"));
    }

    @Test
    void testCheckHealth_WhenDbFails_ReturnsDegradedStatus() {
        when(usuarioRepository.count()).thenThrow(new RuntimeException("Hikari pool timeout"));

        ResponseEntity<Map<String, Object>> response = healthController.checkHealth();

        assertNotNull(response);
        assertEquals(200, response.getStatusCode().value());
        Map<String, Object> body = response.getBody();
        assertNotNull(body);

        assertEquals("DEGRADED", body.get("status"));
        assertEquals("DEGRADED", body.get("database"));
        assertEquals("cajaya-pos-backend", body.get("service"));
    }
}
