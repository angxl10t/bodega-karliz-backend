package com.bodega.backend.controller;

import com.bodega.backend.dto.DevolverGarantiaDTO;
import com.bodega.backend.dto.GarantiaBotellaDTO;
import com.bodega.backend.dto.RegistrarGarantiaDTO;
import com.bodega.backend.dto.ResumenGarantiasDTO;
import com.bodega.backend.service.GarantiaBotellaService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/garantias-botellas")
public class GarantiaBotellaController {

    private final GarantiaBotellaService garantiaService;

    public GarantiaBotellaController(GarantiaBotellaService garantiaService) {
        this.garantiaService = garantiaService;
    }

    @GetMapping
    public ResponseEntity<List<GarantiaBotellaDTO>> listar(
            @RequestParam(required = false) String estado,
            @RequestParam(required = false) String query
    ) {
        return ResponseEntity.ok(garantiaService.listar(estado, query));
    }

    @GetMapping("/resumen")
    public ResponseEntity<ResumenGarantiasDTO> obtenerResumen() {
        return ResponseEntity.ok(garantiaService.obtenerResumen());
    }

    @GetMapping("/{id}")
    public ResponseEntity<GarantiaBotellaDTO> obtenerPorId(@PathVariable Long id) {
        return ResponseEntity.ok(garantiaService.obtenerPorId(id));
    }

    @PostMapping
    public ResponseEntity<GarantiaBotellaDTO> crear(@Valid @RequestBody RegistrarGarantiaDTO dto) {
        return new ResponseEntity<>(garantiaService.crear(dto), HttpStatus.CREATED);
    }

    @PostMapping("/{id}/devolver")
    public ResponseEntity<GarantiaBotellaDTO> devolver(
            @PathVariable Long id,
            @RequestBody(required = false) DevolverGarantiaDTO dto
    ) {
        return ResponseEntity.ok(garantiaService.devolver(id, dto));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        garantiaService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
