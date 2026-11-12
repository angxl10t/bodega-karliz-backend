package com.bodega.backend.controller;

import com.bodega.backend.dto.ReclamacionCreacionDTO;
import com.bodega.backend.dto.ReclamacionDTO;
import com.bodega.backend.dto.ReclamacionRespuestaDTO;
import com.bodega.backend.service.ReclamacionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
public class ReclamacionController {

    private final ReclamacionService reclamacionService;

    // --- ENDPOINTS PÚBLICOS (LIBRO DE RECLAMACIONES VIRTUAL INDECOPI) ---

    @PostMapping("/api/public/reclamaciones")
    public ResponseEntity<ReclamacionDTO> registrarReclamacionPublica(@Valid @RequestBody ReclamacionCreacionDTO dto) {
        ReclamacionDTO resultado = reclamacionService.registrarReclamacion(dto);
        return ResponseEntity.status(HttpStatus.CREATED).body(resultado);
    }

    @GetMapping("/api/public/reclamaciones/{codigo}")
    public ResponseEntity<ReclamacionDTO> consultarReclamacionPublica(
            @PathVariable String codigo,
            @RequestParam(required = false) String documento) {
        ReclamacionDTO resultado = reclamacionService.consultarPorCodigo(codigo, documento);
        return ResponseEntity.ok(resultado);
    }

    // --- ENDPOINTS ADMINISTRATIVOS (GESTIÓN Y RESPUESTA LEGAL) ---

    @GetMapping("/api/reclamaciones")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<List<ReclamacionDTO>> listarReclamaciones() {
        List<ReclamacionDTO> lista = reclamacionService.listarReclamaciones();
        return ResponseEntity.ok(lista);
    }

    @PutMapping("/api/reclamaciones/{id}/responder")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<ReclamacionDTO> responderReclamacion(
            @PathVariable Long id,
            @Valid @RequestBody ReclamacionRespuestaDTO dto) {
        ReclamacionDTO respondida = reclamacionService.responderReclamacion(id, dto);
        return ResponseEntity.ok(respondida);
    }
}
