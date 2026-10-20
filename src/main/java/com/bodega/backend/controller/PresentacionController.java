package com.bodega.backend.controller;

import com.bodega.backend.dto.PresentacionDTO;
import com.bodega.backend.service.PresentacionService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/presentaciones")
public class PresentacionController {

    private final PresentacionService presentacionService;

    public PresentacionController(PresentacionService presentacionService) {
        this.presentacionService = presentacionService;
    }

    @GetMapping("/producto/{idProducto}")
    public ResponseEntity<List<PresentacionDTO>> listarPorProducto(@PathVariable Long idProducto) {
        return ResponseEntity.ok(presentacionService.listarPorProducto(idProducto));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<PresentacionDTO> crear(@Valid @RequestBody PresentacionDTO dto) {
        return new ResponseEntity<>(presentacionService.crear(dto), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<PresentacionDTO> actualizar(@PathVariable Long id, @Valid @RequestBody PresentacionDTO dto) {
        return ResponseEntity.ok(presentacionService.actualizar(id, dto));
    }
    
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<Void> desactivar(@PathVariable Long id) {
        presentacionService.desactivar(id);
        return ResponseEntity.noContent().build();
    }
}
