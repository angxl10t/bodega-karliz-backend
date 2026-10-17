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
}
