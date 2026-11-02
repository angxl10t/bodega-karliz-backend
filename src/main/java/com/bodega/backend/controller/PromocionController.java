package com.bodega.backend.controller;

import com.bodega.backend.dto.PromocionDTO;
import com.bodega.backend.dto.SugerenciaComboHuesoDTO;
import com.bodega.backend.service.PromocionService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/promociones")
public class PromocionController {

    private final PromocionService promocionService;

    public PromocionController(PromocionService promocionService) {
        this.promocionService = promocionService;
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<List<PromocionDTO>> listar() {
        return ResponseEntity.ok(promocionService.listarPromociones());
    }

    @GetMapping("/sugerencias-hueso")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<List<SugerenciaComboHuesoDTO>> obtenerSugerenciasHuesos() {
        return ResponseEntity.ok(promocionService.obtenerSugerenciasCombosHueso());
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<PromocionDTO> crear(@RequestBody PromocionDTO dto) {
        return ResponseEntity.ok(promocionService.crearPromocion(dto));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<PromocionDTO> actualizar(@PathVariable Long id, @RequestBody PromocionDTO dto) {
        return ResponseEntity.ok(promocionService.actualizarPromocion(id, dto));
    }

    @PatchMapping("/{id}/estado")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<PromocionDTO> cambiarEstado(@PathVariable Long id, @RequestBody Map<String, Boolean> body) {
        boolean activo = body.getOrDefault("activo", true);
        return ResponseEntity.ok(promocionService.cambiarEstado(id, activo));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<Map<String, String>> eliminar(@PathVariable Long id) {
        promocionService.eliminarPromocion(id);
        return ResponseEntity.ok(Map.of("mensaje", "Promoción eliminada con éxito"));
    }
}
