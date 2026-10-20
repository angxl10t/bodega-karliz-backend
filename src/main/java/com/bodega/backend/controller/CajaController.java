package com.bodega.backend.controller;

import com.bodega.backend.dto.CierreCajaDTO;
import com.bodega.backend.dto.EgresoCajaDTO;
import com.bodega.backend.dto.FondoCajaDTO;
import com.bodega.backend.service.CajaService;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/caja")
public class CajaController {

    private final CajaService cajaService;

    public CajaController(CajaService cajaService) {
        this.cajaService = cajaService;
    }

    @PostMapping("/egresos")
    @PreAuthorize("hasAnyRole('CAJERO', 'ADMIN', 'SUPERADMIN')")
    public ResponseEntity<EgresoCajaDTO> registrarEgreso(@Valid @RequestBody EgresoCajaDTO dto) {
        EgresoCajaDTO creado = cajaService.registrarEgreso(dto);
        return new ResponseEntity<>(creado, HttpStatus.CREATED);
    }

    @GetMapping("/egresos")
    @PreAuthorize("hasAnyRole('CAJERO', 'ADMIN', 'SUPERADMIN')")
    public ResponseEntity<List<EgresoCajaDTO>> listarEgresos(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fecha) {
        return ResponseEntity.ok(cajaService.listarEgresos(fecha));
    }

    @DeleteMapping("/egresos/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<Void> anularEgreso(
            @PathVariable Long id,
            @RequestParam(required = false) String motivo) {
        cajaService.anularEgreso(id, motivo);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/fondo-inicial")
    @PreAuthorize("hasAnyRole('CAJERO', 'ADMIN', 'SUPERADMIN')")
    public ResponseEntity<FondoCajaDTO> registrarFondoInicial(@Valid @RequestBody FondoCajaDTO dto) {
        return ResponseEntity.ok(cajaService.registrarFondoInicial(dto));
    }

    @GetMapping("/fondo-inicial")
    @PreAuthorize("hasAnyRole('CAJERO', 'ADMIN', 'SUPERADMIN')")
    public ResponseEntity<FondoCajaDTO> obtenerFondoInicial(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fecha) {
        return ResponseEntity.ok(cajaService.obtenerFondoInicial(fecha));
    }

    @GetMapping("/arqueo")
    @PreAuthorize("hasAnyRole('CAJERO', 'ADMIN', 'SUPERADMIN')")
    public ResponseEntity<CierreCajaDTO> obtenerArqueoCompleto(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fecha) {
        return ResponseEntity.ok(cajaService.obtenerArqueoCompleto(fecha));
    }
}
