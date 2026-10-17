package com.bodega.backend.controller;

import com.bodega.backend.dto.ProveedorDTO;
import com.bodega.backend.service.ProveedorService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/proveedores")
public class ProveedorController {

    private final ProveedorService proveedorService;

    public ProveedorController(ProveedorService proveedorService) {
        this.proveedorService = proveedorService;
    }

    @GetMapping
    public ResponseEntity<List<ProveedorDTO>> listarActivos() {
        return ResponseEntity.ok(proveedorService.listarActivos());
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<ProveedorDTO> crear(@Valid @RequestBody ProveedorDTO dto) {
        return new ResponseEntity<>(proveedorService.crear(dto), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<ProveedorDTO> actualizar(@PathVariable Long id, @Valid @RequestBody ProveedorDTO dto) {
        return ResponseEntity.ok(proveedorService.actualizar(id, dto));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<Void> desactivar(@PathVariable Long id) {
        proveedorService.desactivar(id);
        return ResponseEntity.noContent().build();
    }
}
