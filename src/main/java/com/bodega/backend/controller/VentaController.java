package com.bodega.backend.controller;

import com.bodega.backend.dto.CierreCajaDTO;
import com.bodega.backend.dto.VentaDTO;
import com.bodega.backend.service.VentaService;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/ventas")
public class VentaController {

    private final VentaService ventaService;

    public VentaController(VentaService ventaService) {
        this.ventaService = ventaService;
    }

    @GetMapping
    public ResponseEntity<List<VentaDTO>> listarTodas() {
        return ResponseEntity.ok(ventaService.listarTodas());
    }

    @GetMapping("/caja-hoy")
    public ResponseEntity<CierreCajaDTO> obtenerCierreCajaHoy() {
        return ResponseEntity.ok(ventaService.obtenerCierreCajaHoy());
    }

    @GetMapping("/caja")
    public ResponseEntity<CierreCajaDTO> obtenerCierrePorFecha(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fecha) {
        return ResponseEntity.ok(ventaService.obtenerCierreCajaPorFecha(fecha));
    }

    @GetMapping("/caja-historial")
    public ResponseEntity<List<CierreCajaDTO>> obtenerHistorialCierres(
            @RequestParam(defaultValue = "30") int dias) {
        return ResponseEntity.ok(ventaService.obtenerHistorialCierres(dias));
    }

    @PostMapping
    public ResponseEntity<VentaDTO> registrarVenta(@Valid @RequestBody VentaDTO dto) {
        return new ResponseEntity<>(ventaService.registrarVenta(dto), HttpStatus.CREATED);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<Void> anularVenta(
            @PathVariable Long id,
            @RequestParam(required = false) String motivo) {
        ventaService.anularVenta(id, motivo);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/reintentar-sunat")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<VentaDTO> reintentarSunat(@PathVariable Long id) {
        return ResponseEntity.ok(ventaService.reintentarEnvioSunat(id));
    }

    @GetMapping(value = "/exportar-csv", produces = "text/csv; charset=UTF-8")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<byte[]> exportarCsv(
            @RequestParam(required = false) Integer mes,
            @RequestParam(required = false) Integer anio) {
        byte[] csv = ventaService.exportarCsv(mes, anio);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"reporte_ventas.csv\"")
                .header(HttpHeaders.CONTENT_TYPE, "text/csv; charset=UTF-8")
                .body(csv);
    }
}
