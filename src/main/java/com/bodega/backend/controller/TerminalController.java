package com.bodega.backend.controller;

import com.bodega.backend.dto.SolicitudCodigoVinculacionResponseDTO;
import com.bodega.backend.dto.TerminalResponseDTO;
import com.bodega.backend.service.TerminalService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/terminales")
@PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
public class TerminalController {

    private final TerminalService terminalService;

    public TerminalController(TerminalService terminalService) {
        this.terminalService = terminalService;
    }

    /**
     * Genera un código OTP de vinculación (6 dígitos, 10 min de vigencia)
     * para que un nuevo dispositivo móvil o terminal POS se vincule a esta tienda.
     */
    @PostMapping("/solicitar-codigo")
    public ResponseEntity<SolicitudCodigoVinculacionResponseDTO> solicitarCodigo() {
        SolicitudCodigoVinculacionResponseDTO response = terminalService.solicitarCodigoParaSesionActual();
        return ResponseEntity.ok(response);
    }

    /**
     * Retorna todas las terminales registradas y vinculadas a la tienda del administrador.
     */
    @GetMapping
    public ResponseEntity<List<TerminalResponseDTO>> listarTerminales() {
        List<TerminalResponseDTO> terminales = terminalService.listarTerminalesParaSesionActual();
        return ResponseEntity.ok(terminales);
    }

    /**
     * Revoca una terminal inmediatamente (por pérdida, robo o reemplazo de equipo).
     */
    @PostMapping("/{idTerminal}/revocar")
    public ResponseEntity<Map<String, String>> revocarTerminal(@PathVariable Long idTerminal) {
        terminalService.revocarTerminalParaSesionActual(idTerminal);
        return ResponseEntity.ok(Map.of("mensaje", "Terminal revocada exitosamente"));
    }

    @DeleteMapping("/{idTerminal}")
    public ResponseEntity<Map<String, String>> eliminarTerminal(@PathVariable Long idTerminal) {
        terminalService.revocarTerminalParaSesionActual(idTerminal);
        return ResponseEntity.ok(Map.of("mensaje", "Terminal revocada exitosamente"));
    }
}
