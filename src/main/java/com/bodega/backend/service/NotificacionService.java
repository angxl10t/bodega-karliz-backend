package com.bodega.backend.service;

import com.bodega.backend.dto.NotificacionDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Notificacion;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.NotificacionRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;

@Service
public class NotificacionService {

    private static final Logger log = LoggerFactory.getLogger(NotificacionService.class);
    private static final Long SSE_TIMEOUT_MS = 30 * 60 * 1000L; // 30 minutos
    private static final int MAX_SUSCRIPTORES_POR_BODEGA = 15;
    private static final int MAX_SUSCRIPTORES_GLOBAL = 250;

    private final NotificacionRepository notificacionRepository;
    private final List<SseSubscriber> suscriptores = new CopyOnWriteArrayList<>();

    public NotificacionService(NotificacionRepository notificacionRepository) {
        this.notificacionRepository = notificacionRepository;
    }

    public static class SseSubscriber {
        final Long idBodega;
        final Long idUsuario;
        final String rol;
        final SseEmitter emitter;

        public SseSubscriber(Long idBodega, Long idUsuario, String rol, SseEmitter emitter) {
            this.idBodega = idBodega;
            this.idUsuario = idUsuario;
            this.rol = (rol != null) ? rol.trim().toUpperCase() : "CAJERO";
            this.emitter = emitter;
        }

        public boolean coincideDestinatario(Long targetUsuarioId, String targetRol) {
            boolean coincideUsuario = (targetUsuarioId == null) || Objects.equals(this.idUsuario, targetUsuarioId);
            boolean coincideRol = (targetRol == null) || "TODOS".equalsIgnoreCase(targetRol) || this.rol.equalsIgnoreCase(targetRol);
            return coincideUsuario && coincideRol;
        }
    }

    /**
     * Suscribe un cliente HTTP vía Server-Sent Events (SSE).
     * Incluye control de saturación DoS, límite por bodega y desalojo de conexiones huérfanas.
     */
    public SseEmitter suscribir(Long idBodega, Long idUsuario, String rol) {
        if (idBodega == null) {
            throw new IllegalArgumentException("idBodega es requerido para la suscripción SSE");
        }

        // Protección DoS: límite global de suscriptores para no agotar la memoria del contenedor
        if (suscriptores.size() >= MAX_SUSCRIPTORES_GLOBAL) {
            SseSubscriber masAntiguo = suscriptores.isEmpty() ? null : suscriptores.get(0);
            if (masAntiguo != null) {
                try {
                    masAntiguo.emitter.complete();
                } catch (Exception ignored) {}
                suscriptores.remove(masAntiguo);
            }
        }

        // Protección por Bodega: si se supera el máximo por inquilino, desalojar la conexión más antigua del mismo usuario/bodega
        long activosBodega = suscriptores.stream().filter(s -> Objects.equals(s.idBodega, idBodega)).count();
        if (activosBodega >= MAX_SUSCRIPTORES_POR_BODEGA) {
            suscriptores.stream()
                    .filter(s -> Objects.equals(s.idBodega, idBodega) && (idUsuario == null || Objects.equals(s.idUsuario, idUsuario)))
                    .findFirst()
                    .ifPresent(viejo -> {
                        try {
                            viejo.emitter.complete();
                        } catch (Exception ignored) {}
                        suscriptores.remove(viejo);
                    });
        }

        SseEmitter emitter = new SseEmitter(SSE_TIMEOUT_MS);
        SseSubscriber subscriber = new SseSubscriber(idBodega, idUsuario, rol, emitter);
        suscriptores.add(subscriber);

        Runnable cleanup = () -> {
            suscriptores.remove(subscriber);
            log.debug("[SSE] Suscriptor removido [bodega={}, usuario={}, rol={}] Total activos: {}",
                    idBodega, idUsuario, rol, suscriptores.size());
        };

        emitter.onCompletion(cleanup);
        emitter.onTimeout(cleanup);
        emitter.onError(e -> cleanup.run());

        // Enviar evento inicial de conexión con conteo de no leídas
        try {
            long noLeidas = notificacionRepository.contarNoLeidas(idBodega, idUsuario, subscriber.rol);
            emitter.send(SseEmitter.event()
                    .name("INIT")
                    .data(Map.of(
                            "status", "CONNECTED",
                            "noLeidas", noLeidas,
                            "timestamp", System.currentTimeMillis()
                    )));
        } catch (Exception e) {
            cleanup.run();
        }

        log.info("[SSE] Nuevo suscriptor conectado [bodega={}, usuario={}, rol={}] Total activos: {}",
                idBodega, idUsuario, rol, suscriptores.size());

        return emitter;
    }

    /**
     * Heartbeat periódico cada 25 segundos para evitar que proxies y Render cierren conexiones inactivas.
     */
    @Scheduled(fixedRate = 25000)
    public void enviarHeartbeat() {
        if (suscriptores.isEmpty()) return;

        List<SseSubscriber> desconectados = new ArrayList<>();
        for (SseSubscriber sub : suscriptores) {
            try {
                sub.emitter.send(SseEmitter.event().comment("ping"));
            } catch (Exception e) {
                desconectados.add(sub);
            }
        }
        if (!desconectados.isEmpty()) {
            suscriptores.removeAll(desconectados);
            log.debug("[SSE] Limpieza de {} suscriptores inactivos tras heartbeat", desconectados.size());
        }
    }

    /**
     * Guarda la notificación en base de datos y la transmite inmediatamente vía SSE
     * a todos los dispositivos conectados de la bodega que coincidan con el destinatario.
     */
    @Transactional
    public NotificacionDTO crearYNotificar(Bodega bodega,
                                          Usuario usuarioDestinatario,
                                          String rolDestinatario,
                                          String tipo,
                                          String titulo,
                                          String mensaje,
                                          String metadataJson,
                                          String prioridad) {
        if (bodega == null) {
            throw new IllegalArgumentException("Bodega es obligatoria para emitir notificaciones");
        }

        String rolFinal = (rolDestinatario != null && !rolDestinatario.isBlank())
                ? rolDestinatario.trim().toUpperCase()
                : "TODOS";

        Notificacion notif = Notificacion.builder()
                .bodega(bodega)
                .usuarioDestinatario(usuarioDestinatario)
                .rolDestinatario(rolFinal)
                .tipo(tipo.trim().toUpperCase())
                .titulo(titulo.trim())
                .mensaje(mensaje.trim())
                .metadataJson(metadataJson)
                .prioridad((prioridad != null && !prioridad.isBlank()) ? prioridad.trim().toUpperCase() : "MEDIA")
                .leido(false)
                .build();

        Notificacion guardada = notificacionRepository.save(notif);
        NotificacionDTO dto = toDTO(guardada);

        // Transmisión inmediata vía SSE en memoria
        Long idBodega = bodega.getIdBodega();
        Long idTargetUsuario = (usuarioDestinatario != null) ? usuarioDestinatario.getIdUsuario() : null;

        List<SseSubscriber> aRemover = new ArrayList<>();
        for (SseSubscriber sub : suscriptores) {
            if (Objects.equals(sub.idBodega, idBodega) && sub.coincideDestinatario(idTargetUsuario, rolFinal)) {
                try {
                    sub.emitter.send(SseEmitter.event()
                            .name("notificacion")
                            .id(String.valueOf(dto.getIdNotificacion()))
                            .data(dto));
                } catch (Exception e) {
                    aRemover.add(sub);
                }
            }
        }
        if (!aRemover.isEmpty()) {
            suscriptores.removeAll(aRemover);
        }

        log.info("[Notificaciones] Notificación emitida [tipo={}, bodega={}, rol={}] despachada a {} clientes",
                dto.getTipo(), idBodega, rolFinal, suscriptores.size() - aRemover.size());

        return dto;
    }

    @Transactional(readOnly = true)
    public List<NotificacionDTO> listar(Long idBodega, Long idUsuario, String rol, int limite) {
        int limitSeguro = Math.max(1, Math.min(limite, 100));
        String rolNorm = (rol != null) ? rol.trim().toUpperCase() : "CAJERO";
        return notificacionRepository.listarPorBodegaYDestinatario(idBodega, idUsuario, rolNorm, PageRequest.of(0, limitSeguro))
                .stream()
                .map(this::toDTO)
                .toList();
    }

    @Transactional(readOnly = true)
    public long contarNoLeidas(Long idBodega, Long idUsuario, String rol) {
        String rolNorm = (rol != null) ? rol.trim().toUpperCase() : "CAJERO";
        return notificacionRepository.contarNoLeidas(idBodega, idUsuario, rolNorm);
    }

    @Transactional(readOnly = true)
    public boolean existeAlertaStockPendiente(Long idBodega, Long idProducto, boolean agotado) {
        if (idBodega == null || idProducto == null) return false;
        String prodFilter = "\"idProducto\":" + idProducto + ",";
        String tituloLike = agotado ? "%Agotado%" : null;
        return notificacionRepository.existeAlertaStockPendiente(idBodega, prodFilter, tituloLike);
    }

    @Transactional
    public boolean marcarComoLeida(Long idBodega, Long idUsuario, String rol, Long idNotificacion) {
        Optional<Notificacion> opt = notificacionRepository.findById(idNotificacion);
        if (opt.isPresent()) {
            Notificacion n = opt.get();
            if (Objects.equals(n.getBodega().getIdBodega(), idBodega)) {
                String rolNorm = (rol != null) ? rol.trim().toUpperCase() : "CAJERO";
                boolean esAdmin = "ADMIN".equalsIgnoreCase(rolNorm) || "SUPERADMIN".equalsIgnoreCase(rolNorm);
                boolean esDestinatarioUsuario = n.getUsuarioDestinatario() == null
                        || (idUsuario != null && Objects.equals(n.getUsuarioDestinatario().getIdUsuario(), idUsuario));
                boolean esDestinatarioRol = "TODOS".equalsIgnoreCase(n.getRolDestinatario())
                        || n.getRolDestinatario() == null
                        || n.getRolDestinatario().equalsIgnoreCase(rolNorm);

                if (esAdmin || (esDestinatarioUsuario && esDestinatarioRol)) {
                    n.setLeido(true);
                    n.setFechaLeido(OffsetDateTime.now());
                    notificacionRepository.save(n);
                    return true;
                }
            }
        }
        return false;
    }

    @Transactional
    public int marcarTodasComoLeidas(Long idBodega, Long idUsuario, String rol) {
        String rolNorm = (rol != null) ? rol.trim().toUpperCase() : "CAJERO";
        return notificacionRepository.marcarTodasComoLeidas(idBodega, idUsuario, rolNorm, OffsetDateTime.now());
    }

    public NotificacionDTO toDTO(Notificacion n) {
        return NotificacionDTO.builder()
                .idNotificacion(n.getIdNotificacion())
                .idBodega(n.getBodega().getIdBodega())
                .idUsuarioDestinatario(n.getUsuarioDestinatario() != null ? n.getUsuarioDestinatario().getIdUsuario() : null)
                .rolDestinatario(n.getRolDestinatario())
                .tipo(n.getTipo())
                .titulo(n.getTitulo())
                .mensaje(n.getMensaje())
                .metadataJson(n.getMetadataJson())
                .prioridad(n.getPrioridad())
                .leido(n.getLeido())
                .fechaCreacion(n.getFechaCreacion())
                .fechaLeido(n.getFechaLeido())
                .build();
    }
}
