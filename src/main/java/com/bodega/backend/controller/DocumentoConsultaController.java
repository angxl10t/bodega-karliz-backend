package com.bodega.backend.controller;

import com.bodega.backend.dto.DniConsultaDTO;
import com.bodega.backend.dto.RucConsultaDTO;
import com.bodega.backend.service.DocumentoConsultaService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping({"/api/v1/documentos", "/api/documentos"})
public class DocumentoConsultaController {

    private final DocumentoConsultaService documentoConsultaService;

    public DocumentoConsultaController(DocumentoConsultaService documentoConsultaService) {
        this.documentoConsultaService = documentoConsultaService;
    }

    @GetMapping("/dni/{numero}")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<DniConsultaDTO> consultarDni(@PathVariable String numero) {
        return ResponseEntity.ok(documentoConsultaService.consultarDni(numero));
    }

    @GetMapping("/ruc/{numero}")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<RucConsultaDTO> consultarRuc(@PathVariable String numero) {
        return ResponseEntity.ok(documentoConsultaService.consultarRuc(numero));
    }
}
