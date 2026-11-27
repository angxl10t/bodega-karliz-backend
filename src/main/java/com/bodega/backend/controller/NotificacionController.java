package com.bodega.backend.controller;

import com.bodega.backend.dto.NotificacionDTO;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.UsuarioRepository;
import com.bodega.backend.service.NotificacionService;
import com.bodega.backend.service.TenantService;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/notificaciones")
public class NotificacionController {

    private final NotificacionService notificacionService;
    private final TenantService tenantService;
    private final UsuarioRepository usuarioRepository;

    public NotificacionController(NotificacionService notificacionService,
                                  TenantService tenantService,
                                  UsuarioRepository usuarioRepository) {
        this.notificacionService = notificacionService;
        this.tenantService = tenantService;
        this.usuarioRepository = usuarioRepository;
    }

    private UserSessionInfo resolveUserSession() {
        Long idBodega = tenantService.getCurrentBodegaId();
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        Long idUsuario = null;
        String rol = "CAJERO";

        if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) {
            Optional<Usuario> optUser = usuarioRepository.findByUsername(auth.getName());
            if (optUser.isPresent()) {
                Usuario u = optUser.get();
                idUsuario = u.getIdUsuario();
                rol = u.getRol() != null ? u.getRol().toUpperCase() : "CAJERO";
            }
        }
        return new UserSessionInfo(idBodega, idUsuario, rol);
    }

    private static class UserSessionInfo {
        final Long idBodega;
        final Long idUsuario;
        final String rol;

        UserSessionInfo(Long idBodega, Long idUsuario, String rol) {
            this.idBodega = idBodega;
            this.idUsuario = idUsuario;
            this.rol = rol;
        }
    }

    /**
     * Canal SSE en tiempo real:
     * Abre un stream persistente con el servidor (Server-Sent Events) para recibir
     * alertas instantáneas de Pedidos Web y Stock Crítico según el rol del usuario.
     */
    @GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter streamNotificaciones() {
        UserSessionInfo s = resolveUserSession();
        return notificacionService.suscribir(s.idBodega, s.idUsuario, s.rol);
    }

    /**
     * Lista el historial de notificaciones recientes para la bandeja de entrada.
     */
    @GetMapping
    public ResponseEntity<List<NotificacionDTO>> listarNotificaciones(
            @RequestParam(required = false, defaultValue = "30") int limite) {
        UserSessionInfo s = resolveUserSession();
        List<NotificacionDTO> lista = notificacionService.listar(s.idBodega, s.idUsuario, s.rol, limite);
        return ResponseEntity.ok(lista);
    }

    /**
     * Conteo rápido de notificaciones no leídas para el badge de la campana.
     */
    @GetMapping("/conteo-no-leidas")
    public ResponseEntity<Map<String, Object>> conteoNoLeidas() {
        UserSessionInfo s = resolveUserSession();
        long noLeidas = notificacionService.contarNoLeidas(s.idBodega, s.idUsuario, s.rol);
        return ResponseEntity.ok(Map.of("noLeidas", noLeidas));
    }

    /**
     * Marca una notificación como leída.
     */
    @PutMapping("/{id}/leer")
    public ResponseEntity<Map<String, Object>> marcarComoLeida(@PathVariable Long id) {
        Long idBodega = tenantService.getCurrentBodegaId();
        boolean ok = notificacionService.marcarComoLeida(idBodega, id);
        return ResponseEntity.ok(Map.of("exito", ok, "idNotificacion", id));
    }

    /**
     * Marca todas las notificaciones pendientes como leídas.
     */
    @PutMapping("/marcar-todas")
    public ResponseEntity<Map<String, Object>> marcarTodasComoLeidas() {
        UserSessionInfo s = resolveUserSession();
        int actualizadas = notificacionService.marcarTodasComoLeidas(s.idBodega, s.idUsuario, s.rol);
        return ResponseEntity.ok(Map.of("exito", true, "actualizadas", actualizadas));
    }
}
