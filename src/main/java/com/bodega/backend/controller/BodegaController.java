package com.bodega.backend.controller;

import com.bodega.backend.dto.ActualizarBodegaDTO;
import com.bodega.backend.dto.BodegaDTO;
import com.bodega.backend.security.ClientIpUtil;
import com.bodega.backend.security.PagoRateLimiterService;
import com.bodega.backend.service.BodegaService;
import com.bodega.backend.service.TenantService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/bodegas")
public class BodegaController {

    private final BodegaService bodegaService;
    private final PagoRateLimiterService pagoRateLimiterService;
    private final TenantService tenantService;

    public BodegaController(BodegaService bodegaService,
                            PagoRateLimiterService pagoRateLimiterService,
                            TenantService tenantService) {
        this.bodegaService = bodegaService;
        this.pagoRateLimiterService = pagoRateLimiterService;
        this.tenantService = tenantService;
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
    public ResponseEntity<BodegaDTO> registrarPagoYape(
            @Valid @RequestBody com.bodega.backend.dto.PagoYapeDTO dto,
            HttpServletRequest request) {

        String clientIp = ClientIpUtil.extractClientIp(request);
        Long idBodega = tenantService != null ? tenantService.getCurrentBodegaId() : null;

        if (pagoRateLimiterService != null && pagoRateLimiterService.isBlocked(clientIp, idBodega)) {
            long remaining = pagoRateLimiterService.getRemainingBlockMinutes(clientIp, idBodega);
            throw new ResponseStatusException(
                HttpStatus.TOO_MANY_REQUESTS,
                "Demasiados intentos fallidos con códigos de operación. Por seguridad bancaria, la validación de pagos está temporalmente bloqueada por " + remaining + " minuto(s)."
            );
        }

        try {
            BodegaDTO actualizada = bodegaService.registrarPagoYape(dto);
            if (pagoRateLimiterService != null) {
                pagoRateLimiterService.resetAttempts(clientIp, idBodega);
            }
            return ResponseEntity.ok(actualizada);
        } catch (RuntimeException ex) {
            if (pagoRateLimiterService != null) {
                pagoRateLimiterService.registerFailedAttempt(clientIp, idBodega);
            }
            throw ex;
        }
    }

    public ResponseEntity<BodegaDTO> registrarPagoYape(com.bodega.backend.dto.PagoYapeDTO dto) {
        return registrarPagoYape(dto, null);
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
        return ResponseEntity.status(HttpStatus.CREATED)
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
