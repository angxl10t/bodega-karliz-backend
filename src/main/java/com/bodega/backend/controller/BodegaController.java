package com.bodega.backend.controller;

import com.bodega.backend.dto.ActualizarBodegaDTO;
import com.bodega.backend.dto.BodegaDTO;
import com.bodega.backend.service.BodegaService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/bodegas")
public class BodegaController {

    private final BodegaService bodegaService;

    public BodegaController(BodegaService bodegaService) {
        this.bodegaService = bodegaService;
    }

    @GetMapping("/mi-bodega")
    public ResponseEntity<BodegaDTO> obtenerMiBodega() {
        return ResponseEntity.ok(bodegaService.obtenerMiBodega());
    }

    @GetMapping
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<java.util.List<BodegaDTO>> listarTodas() {
        return ResponseEntity.ok(bodegaService.listarTodas());
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<BodegaDTO> obtenerPorId(@PathVariable Long id) {
        return ResponseEntity.ok(bodegaService.obtenerPorId(id));
    }

    @PutMapping("/configuracion")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<BodegaDTO> actualizarConfiguracion(@Valid @RequestBody ActualizarBodegaDTO dto) {
        BodegaDTO actualizada = bodegaService.actualizarConfiguracion(dto);
        return ResponseEntity.ok(actualizada);
    }

    @PostMapping("/pago-yape")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<BodegaDTO> registrarPagoYape(@Valid @RequestBody com.bodega.backend.dto.PagoYapeDTO dto) {
        BodegaDTO actualizada = bodegaService.registrarPagoYape(dto);
        return ResponseEntity.ok(actualizada);
    }

    @PutMapping("/configuracion-sunat")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<BodegaDTO> actualizarConfiguracionSunat(@Valid @RequestBody com.bodega.backend.dto.ConfiguracionSunatDTO dto) {
        BodegaDTO actualizada = bodegaService.actualizarConfiguracionSunat(dto);
        return ResponseEntity.ok(actualizada);
    }

    @GetMapping("/mis-pagos")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<java.util.List<com.bodega.backend.dto.PagoSuscripcionDTO>> listarMisPagos() {
        return ResponseEntity.ok(bodegaService.listarMisPagos());
    }

    @GetMapping("/todos-los-pagos")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<java.util.List<com.bodega.backend.dto.PagoSuscripcionDTO>> listarTodosLosPagos() {
        return ResponseEntity.ok(bodegaService.listarTodosLosPagos());
    }

    @PutMapping("/{id}/estado")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<BodegaDTO> cambiarEstadoBodega(
            @PathVariable Long id,
            @RequestParam boolean activo) {
        return ResponseEntity.ok(bodegaService.cambiarEstadoBodega(id, activo));
    }

    @PutMapping("/{id}/plan")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<BodegaDTO> cambiarPlanBodega(
            @PathVariable Long id,
            @RequestParam String plan,
            @RequestParam(required = false, defaultValue = "30") Integer dias) {
        return ResponseEntity.ok(bodegaService.cambiarPlanBodega(id, plan, dias));
    }

    @GetMapping("/metricas-sistema")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<java.util.Map<String, Object>> obtenerMetricasSistema() {
        return ResponseEntity.ok(bodegaService.obtenerMetricasSistema());
    }

    @PostMapping("/provisionar")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<BodegaDTO> provisionarBodega(
            @jakarta.validation.Valid @RequestBody com.bodega.backend.dto.ProvisionarBodegaDTO dto) {
        return ResponseEntity.status(org.springframework.http.HttpStatus.CREATED)
                .body(bodegaService.provisionarBodega(dto));
    }

    @PutMapping("/pagos/{id}/estado")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<com.bodega.backend.dto.PagoSuscripcionDTO> cambiarEstadoPago(
            @PathVariable Long id,
            @RequestParam String estado) {
        return ResponseEntity.ok(bodegaService.cambiarEstadoPago(id, estado));
    }

    @GetMapping("/anuncio-global")
    public ResponseEntity<java.util.Map<String, Object>> obtenerAnuncioGlobal() {
        return ResponseEntity.ok(bodegaService.obtenerAnuncioGlobal());
    }

    @PostMapping("/anuncio-global")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<java.util.Map<String, Object>> publicarAnuncioGlobal(
            @RequestBody java.util.Map<String, Object> req) {
        return ResponseEntity.ok(bodegaService.publicarAnuncioGlobal(req));
    }

    @DeleteMapping("/anuncio-global")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<java.util.Map<String, String>> eliminarAnuncioGlobal() {
        bodegaService.eliminarAnuncioGlobal();
        return ResponseEntity.ok(java.util.Map.of("mensaje", "Anuncio global eliminado exitosamente"));
    }
}
