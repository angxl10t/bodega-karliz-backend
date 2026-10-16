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

    @PutMapping("/configuracion")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<BodegaDTO> actualizarConfiguracion(@Valid @RequestBody ActualizarBodegaDTO dto) {
        BodegaDTO actualizada = bodegaService.actualizarConfiguracion(dto);
        return ResponseEntity.ok(actualizada);
    }
}
