package com.bodega.backend.controller;

import com.bodega.backend.dto.CierreCajaDTO;
import com.bodega.backend.dto.VentaDTO;
import com.bodega.backend.service.VentaService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

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

    @PostMapping
    public ResponseEntity<VentaDTO> registrarVenta(@Valid @RequestBody VentaDTO dto) {
        return new ResponseEntity<>(ventaService.registrarVenta(dto), HttpStatus.CREATED);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> anularVenta(@PathVariable Long id) {
        ventaService.anularVenta(id);
        return ResponseEntity.noContent().build();
    }
}
