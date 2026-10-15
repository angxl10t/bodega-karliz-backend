package com.bodega.backend.controller;

import com.bodega.backend.dto.MovimientoInventarioDTO;
import com.bodega.backend.service.MovimientoService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/movimientos")
@PreAuthorize("hasRole('ADMIN')")
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
}
