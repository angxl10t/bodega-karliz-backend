package com.bodega.backend.controller;

import com.bodega.backend.dto.VentaDTO;
import com.bodega.backend.service.VentaService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/ventas")
public class VentaController {

    private final VentaService ventaService;

    public VentaController(VentaService ventaService) {
        this.ventaService = ventaService;
    }

    @PostMapping
    public ResponseEntity<VentaDTO> registrarVenta(@Valid @RequestBody VentaDTO dto) {
        return new ResponseEntity<>(ventaService.registrarVenta(dto), HttpStatus.CREATED);
    }
}
