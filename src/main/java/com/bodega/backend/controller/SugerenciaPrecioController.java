package com.bodega.backend.controller;

import com.bodega.backend.dto.CrearSugerenciaSuperadminDTO;
import com.bodega.backend.dto.SugerenciaPrecioDTO;
import com.bodega.backend.service.SugerenciaPrecioService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
public class SugerenciaPrecioController {

    private final SugerenciaPrecioService sugerenciaPrecioService;

    public SugerenciaPrecioController(SugerenciaPrecioService sugerenciaPrecioService) {
        this.sugerenciaPrecioService = sugerenciaPrecioService;
    }

    // =========================================================================
    // ENDPOINTS SUPERADMIN
    // =========================================================================

    @PostMapping("/api/superadmin/sugerencias-precio")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<Map<String, Object>> difundirSugerencia(@Valid @RequestBody CrearSugerenciaSuperadminDTO dto) {
        int notificadas = sugerenciaPrecioService.difundirSugerencia(dto);
        return ResponseEntity.ok(Map.of(
                "mensaje", "Sugerencia difundida exitosamente a " + notificadas + " bodegas.",
                "bodegasNotificadas", notificadas
        ));
    }

    @GetMapping("/api/superadmin/sugerencias-precio")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<List<SugerenciaPrecioDTO>> listarParaSuperadmin(
            @RequestParam(required = false) String estado) {
        return ResponseEntity.ok(sugerenciaPrecioService.listarParaSuperadmin(estado));
    }

    @GetMapping("/api/superadmin/sugerencias-precio/conteo-bodegas")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<Map<String, Object>> contarBodegasConProducto(
            @RequestParam String codigoBarras) {
        long conteo = sugerenciaPrecioService.contarBodegasConProducto(codigoBarras);
        return ResponseEntity.ok(Map.of(
                "codigoBarras", codigoBarras,
                "bodegasConProducto", conteo
        ));
    }

    @GetMapping("/api/superadmin/sugerencias-precio/estadisticas")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<Map<String, Object>> obtenerEstadisticas() {
        return ResponseEntity.ok(sugerenciaPrecioService.obtenerEstadisticas());
    }

    // =========================================================================
    // ENDPOINTS BODEGA TENANT
    // =========================================================================

    @GetMapping("/api/bodegas/mis-sugerencias-precio")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<List<SugerenciaPrecioDTO>> listarParaBodega(
            @RequestParam(required = false, defaultValue = "PENDIENTE") String estado) {
        return ResponseEntity.ok(sugerenciaPrecioService.listarParaBodegaActual(estado));
    }

    @GetMapping("/api/bodegas/mis-sugerencias-precio/conteo")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN', 'CAJERO')")
    public ResponseEntity<Map<String, Object>> contarPendientesBodega() {
        long pendientes = sugerenciaPrecioService.contarPendientesParaBodegaActual();
        return ResponseEntity.ok(Map.of("pendientes", pendientes));
    }

    @PutMapping("/api/bodegas/mis-sugerencias-precio/{id}/aceptar")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<SugerenciaPrecioDTO> aceptarSugerencia(@PathVariable Long id) {
        return ResponseEntity.ok(sugerenciaPrecioService.aceptarSugerencia(id));
    }

    @PutMapping("/api/bodegas/mis-sugerencias-precio/{id}/rechazar")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<SugerenciaPrecioDTO> rechazarSugerencia(@PathVariable Long id) {
        return ResponseEntity.ok(sugerenciaPrecioService.rechazarSugerencia(id));
    }

    @PutMapping("/api/bodegas/mis-sugerencias-precio/aceptar-todas")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<Map<String, Object>> aceptarTodas() {
        int total = sugerenciaPrecioService.aceptarTodasParaBodegaActual();
        return ResponseEntity.ok(Map.of(
                "mensaje", "Se aceptaron " + total + " sugerencias exitosamente.",
                "totalAceptadas", total
        ));
    }

    @PutMapping("/api/bodegas/mis-sugerencias-precio/rechazar-todas")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<Map<String, Object>> rechazarTodas() {
        int total = sugerenciaPrecioService.rechazarTodasParaBodegaActual();
        return ResponseEntity.ok(Map.of(
                "mensaje", "Se rechazaron " + total + " sugerencias.",
                "totalRechazadas", total
        ));
    }
}
