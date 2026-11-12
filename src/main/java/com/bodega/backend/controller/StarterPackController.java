package com.bodega.backend.controller;

import com.bodega.backend.dto.StarterPackPresetDTO;
import com.bodega.backend.service.StarterPackService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/superadmin/starter-pack")
@PreAuthorize("hasRole('SUPERADMIN')")
public class StarterPackController {

    private final StarterPackService starterPackService;

    public StarterPackController(StarterPackService starterPackService) {
        this.starterPackService = starterPackService;
    }

    @GetMapping
    public ResponseEntity<List<StarterPackPresetDTO>> listarPreset() {
        return ResponseEntity.ok(starterPackService.listarPresetGlobal());
    }

    @PostMapping
    public ResponseEntity<StarterPackPresetDTO> crearItem(@Valid @RequestBody StarterPackPresetDTO dto) {
        return ResponseEntity.status(HttpStatus.CREATED).body(starterPackService.crearPresetItem(dto));
    }

    @PutMapping("/{id}")
    public ResponseEntity<StarterPackPresetDTO> actualizarItem(
            @PathVariable Long id,
            @Valid @RequestBody StarterPackPresetDTO dto) {
        return ResponseEntity.ok(starterPackService.actualizarPresetItem(id, dto));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, String>> eliminarItem(@PathVariable Long id) {
        starterPackService.eliminarPresetItem(id);
        return ResponseEntity.ok(Map.of("mensaje", "Producto eliminado del preset global exitosamente."));
    }

    @PostMapping("/restablecer")
    public ResponseEntity<List<StarterPackPresetDTO>> restablecerPreset() {
        return ResponseEntity.ok(starterPackService.restablecerPresetGlobal());
    }
}
