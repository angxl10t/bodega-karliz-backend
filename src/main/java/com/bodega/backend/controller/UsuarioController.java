package com.bodega.backend.controller;

import com.bodega.backend.dto.UsuarioDTO;
import com.bodega.backend.service.UsuarioService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/usuarios")
@PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
public class UsuarioController {

    private final UsuarioService usuarioService;

    public UsuarioController(UsuarioService usuarioService) {
        this.usuarioService = usuarioService;
    }

    @GetMapping
    public ResponseEntity<List<UsuarioDTO>> listarTodos() {
        return ResponseEntity.ok(usuarioService.listarTodos());
    }

    @PostMapping
    public ResponseEntity<UsuarioDTO> crearUsuario(@Valid @RequestBody UsuarioDTO dto) {
        UsuarioDTO creado = usuarioService.crearUsuario(dto);
        return ResponseEntity.status(HttpStatus.CREATED).body(creado);
    }

    @PatchMapping("/{id}/estado")
    public ResponseEntity<UsuarioDTO> cambiarEstado(
            @PathVariable Long id,
            @RequestParam boolean activo,
            Principal principal) {
        String adminActual = principal != null ? principal.getName() : "";
        UsuarioDTO actualizado = usuarioService.cambiarEstado(id, activo, adminActual);
        return ResponseEntity.ok(actualizado);
    }

    @PutMapping("/{id}/reset-password")
    public ResponseEntity<Map<String, String>> resetearPassword(
            @PathVariable Long id,
            @RequestBody Map<String, String> body,
            Principal principal) {
        String adminActual = principal != null ? principal.getName() : "";
        String nuevaPassword = (body != null) ? body.get("nuevaPassword") : null;
        usuarioService.resetearPassword(id, nuevaPassword, adminActual);
        Map<String, String> res = new HashMap<>();
        res.put("mensaje", "Contraseña restablecida exitosamente.");
        return ResponseEntity.ok(res);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, String>> desactivarUsuario(
            @PathVariable Long id,
            Principal principal) {
        String adminActual = principal != null ? principal.getName() : "";
        usuarioService.cambiarEstado(id, false, adminActual);
        Map<String, String> res = new HashMap<>();
        res.put("mensaje", "Usuario desactivado exitosamente.");
        return ResponseEntity.ok(res);
    }
}
