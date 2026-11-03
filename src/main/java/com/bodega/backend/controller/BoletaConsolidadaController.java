package com.bodega.backend.controller;

import com.bodega.backend.dto.BoletaConsolidadaDTO;
import com.bodega.backend.dto.RegistrarBoletaConsolidadaDTO;
import com.bodega.backend.dto.ResumenVentasMenoresDTO;
import com.bodega.backend.service.BoletaConsolidadaService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

/**
 * Endpoints para la gestión y registro manual de la Boleta Consolidada Diaria
 * por ventas menores a S/ 5.00 en el Nuevo RUS (Res. SUNAT N° 007-99 Art. 8, Num 3.2).
 */
@RestController
@RequestMapping("/api/bodegas/fiscal/boleta-consolidada")
@RequiredArgsConstructor
public class BoletaConsolidadaController {

    private final BoletaConsolidadaService boletaConsolidadaService;

    @GetMapping("/sugerencia")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN', 'CAJERO')")
    public ResponseEntity<ResumenVentasMenoresDTO> obtenerSugerencia(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fecha) {
        return ResponseEntity.ok(boletaConsolidadaService.obtenerSugerencia(fecha));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN', 'CAJERO')")
    public ResponseEntity<BoletaConsolidadaDTO> registrarBoletaConsolidada(
            @Valid @RequestBody RegistrarBoletaConsolidadaDTO dto) {
        return ResponseEntity.ok(boletaConsolidadaService.registrarBoletaConsolidada(dto));
    }

    @GetMapping("/historial")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN', 'CAJERO')")
    public ResponseEntity<List<BoletaConsolidadaDTO>> listarHistorial(
            @RequestParam(required = false, defaultValue = "30") Integer limit) {
        return ResponseEntity.ok(boletaConsolidadaService.listarHistorial(limit));
    }
}
