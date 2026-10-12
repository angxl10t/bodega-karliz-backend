package com.bodega.backend.controller;

import com.bodega.backend.dto.CompraDTO;
import com.bodega.backend.service.CompraService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/compras")
public class CompraController {

    private final CompraService compraService;

    public CompraController(CompraService compraService) {
        this.compraService = compraService;
    }

    @GetMapping
    public ResponseEntity<List<CompraDTO>> listarTodas() {
        return ResponseEntity.ok(compraService.listarTodas());
    }

    @PostMapping
    public ResponseEntity<CompraDTO> registrarCompra(@Valid @RequestBody CompraDTO dto) {
        return new ResponseEntity<>(compraService.registrarCompra(dto), HttpStatus.CREATED);
    }
}
