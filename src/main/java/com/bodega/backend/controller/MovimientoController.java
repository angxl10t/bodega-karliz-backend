package com.bodega.backend.controller;

import com.bodega.backend.dto.AjusteInventarioDTO;
import com.bodega.backend.dto.MovimientoInventarioDTO;
import com.bodega.backend.service.MovimientoService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/movimientos")
@PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
public class MovimientoController {

    private final MovimientoService movimientoService;

    public MovimientoController(MovimientoService movimientoService) {
        this.movimientoService = movimientoService;
    }

    @GetMapping
    public ResponseEntity<List<MovimientoInventarioDTO>> listarTodos() {
        return ResponseEntity.ok(movimientoService.listarTodos());
    }

    @GetMapping("/producto/{idProducto}")
    public ResponseEntity<List<MovimientoInventarioDTO>> listarPorProducto(@PathVariable Long idProducto) {
        return ResponseEntity.ok(movimientoService.listarPorProducto(idProducto));
    }

    @PostMapping("/ajuste")
    public ResponseEntity<MovimientoInventarioDTO> registrarAjuste(@Valid @RequestBody AjusteInventarioDTO dto) {
        return ResponseEntity.ok(movimientoService.registrarAjuste(dto));
    }
}
