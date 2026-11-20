package com.bodega.backend.service;

import com.bodega.backend.dto.SolicitudCodigoVinculacionResponseDTO;
import com.bodega.backend.dto.TerminalResponseDTO;
import com.bodega.backend.dto.VincularTerminalRequestDTO;
import com.bodega.backend.dto.VincularTerminalResponseDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.TerminalPOS;
import com.bodega.backend.entity.TerminalPairingCode;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.TerminalPairingCodeRepository;
import com.bodega.backend.repository.TerminalRepository;
import com.bodega.backend.repository.UsuarioRepository;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class TerminalService {

    private final TerminalRepository terminalRepository;
    private final TerminalPairingCodeRepository pairingCodeRepository;
    private final BodegaRepository bodegaRepository;
    private final UsuarioRepository usuarioRepository;
    private final SecureRandom secureRandom = new SecureRandom();

    public TerminalService(TerminalRepository terminalRepository,
                           TerminalPairingCodeRepository pairingCodeRepository,
                           BodegaRepository bodegaRepository,
                           UsuarioRepository usuarioRepository) {
        this.terminalRepository = terminalRepository;
        this.pairingCodeRepository = pairingCodeRepository;
        this.bodegaRepository = bodegaRepository;
        this.usuarioRepository = usuarioRepository;
    }

    /**
     * Genera un código de emparejamiento OTP de un solo uso (TTL: 10 minutos)
     * solicitado exclusivamente por un Dueño/Admin autenticado.
     */
    @Transactional
    public SolicitudCodigoVinculacionResponseDTO generarCodigoVinculacion(Long idBodega, String username) {
        Bodega bodega = bodegaRepository.findById(idBodega)
                .orElseThrow(() -> new IllegalArgumentException("Negocio no encontrado"));

        if (!Boolean.TRUE.equals(bodega.getEstado())) {
            throw new IllegalStateException("El negocio se encuentra inactivo");
        }

        // Marcar como usados códigos previos activos para evitar ambigüedades
        OffsetDateTime now = OffsetDateTime.now();
        List<TerminalPairingCode> previos = pairingCodeRepository
                .findByBodega_IdBodegaAndUsadoFalseAndFechaExpiracionAfter(idBodega, now);
        for (TerminalPairingCode p : previos) {
            p.setUsado(true);
        }
        if (!previos.isEmpty()) {
            pairingCodeRepository.saveAll(previos);
        }

        // Generar código numérico de 6 dígitos de alta entropía (100,000 a 999,999)
        int numero = 100000 + secureRandom.nextInt(900000);
        String codigo = String.valueOf(numero);

        TerminalPairingCode pairing = new TerminalPairingCode();
        pairing.setBodega(bodega);
        pairing.setCodigo(codigo);
        pairing.setFechaExpiracion(now.plusMinutes(10));
        pairing.setUsado(false);
        pairing.setCreadoPorUsername(username);
        pairingCodeRepository.save(pairing);

        String qrPayload = "cajaya://pair?code=" + codigo + "&tienda=" + UriUtils(bodega.getNombreComercial());

        return SolicitudCodigoVinculacionResponseDTO.builder()
                .codigo(codigo)
                .expiraEnSegundos(600)
                .qrPayload(qrPayload)
                .nombreBodega(bodega.getNombreComercial())
                .idBodega(bodega.getIdBodega())
                .build();
    }

    /**
     * Canjea el código de emparejamiento desde la nueva terminal y le entrega
     * un token criptográfico persistente (X-Terminal-Token).
     */
    @Transactional
    public VincularTerminalResponseDTO vincularTerminal(VincularTerminalRequestDTO dto, String clientIp) {
        String codigoLimpio = dto.getCodigoEmparejamiento() != null
                ? dto.getCodigoEmparejamiento().trim().replaceAll("[^0-9A-Za-z]", "").toUpperCase()
                : "";

        if (codigoLimpio.isBlank()) {
            throw new IllegalArgumentException("El código de emparejamiento es obligatorio");
        }

        OffsetDateTime now = OffsetDateTime.now();
        TerminalPairingCode pairing = pairingCodeRepository.findByCodigoAndUsadoFalse(codigoLimpio)
                .orElseThrow(() -> new IllegalArgumentException("Código de vinculación inválido o ya utilizado"));

        if (now.isAfter(pairing.getFechaExpiracion())) {
            pairing.setUsado(true);
            pairingCodeRepository.save(pairing);
            throw new IllegalArgumentException("El código de vinculación ha expirado. Solicita uno nuevo en el panel de Administrador");
        }

        Bodega bodega = pairing.getBodega();
        if (!Boolean.TRUE.equals(bodega.getEstado())) {
            throw new IllegalStateException("El local al que intentas vincularte se encuentra deshabilitado");
        }

        // Marcar código como usado inmediatamente (Single Use)
        pairing.setUsado(true);
        pairingCodeRepository.save(pairing);

        // Generar token criptográfico único para este dispositivo
        String terminalToken = "term_" + UUID.randomUUID().toString().replace("-", "") + "_"
                + Long.toHexString(System.currentTimeMillis());

        long countActivas = terminalRepository.countByBodega_IdBodegaAndEstadoTrue(bodega.getIdBodega());
        String nombreTerminal = (dto.getNombreTerminal() != null && !dto.getNombreTerminal().isBlank())
                ? dto.getNombreTerminal().trim()
                : "Terminal Caja " + (countActivas + 1);

        TerminalPOS terminal = new TerminalPOS();
        terminal.setBodega(bodega);
        terminal.setNombre(nombreTerminal);
        terminal.setTerminalToken(terminalToken);
        terminal.setDeviceModel(dto.getDeviceModel() != null ? dto.getDeviceModel().trim() : "Terminal Móvil POS");
        terminal.setFechaVinculacion(now);
        terminal.setUltimoAcceso(now);
        terminal.setEstado(true);

        TerminalPOS guardada = terminalRepository.save(terminal);

        return VincularTerminalResponseDTO.builder()
                .terminalToken(guardada.getTerminalToken())
                .idBodega(bodega.getIdBodega())
                .nombreBodega(bodega.getNombreComercial())
                .nombreTerminal(guardada.getNombre())
                .idTerminal(guardada.getIdTerminal())
                .build();
    }

    /**
     * Valida un X-Terminal-Token recibido en los headers de solicitudes de terminal.
     */
    @Transactional
    public TerminalPOS validarTerminalToken(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            return null;
        }

        String token = rawToken.trim();
        if (token.startsWith("Bearer ") || token.startsWith("bearer ")) {
            token = token.substring(7).trim();
        }

        TerminalPOS terminal = terminalRepository.findByTerminalTokenAndEstadoTrue(token).orElse(null);
        if (terminal != null) {
            terminal.setUltimoAcceso(OffsetDateTime.now());
            terminalRepository.save(terminal);
        }
        return terminal;
    }

    /**
     * Lista todas las terminales asociadas al negocio para gestión del dueño.
     */
    @Transactional(readOnly = true)
    public List<TerminalResponseDTO> listarTerminales(Long idBodega) {
        return terminalRepository.findByBodega_IdBodegaOrderByFechaVinculacionDesc(idBodega)
                .stream()
                .map(t -> TerminalResponseDTO.builder()
                        .idTerminal(t.getIdTerminal())
                        .nombre(t.getNombre())
                        .deviceModel(t.getDeviceModel())
                        .fechaVinculacion(t.getFechaVinculacion())
                        .ultimoAcceso(t.getUltimoAcceso())
                        .estado(t.getEstado())
                        .build())
                .collect(Collectors.toList());
    }

    /**
     * Revoca inmediatamente el acceso a una terminal perdida o no autorizada.
     */
    @Transactional
    public void revocarTerminal(Long idBodega, Long idTerminal) {
        TerminalPOS terminal = terminalRepository.findById(idTerminal)
                .orElseThrow(() -> new IllegalArgumentException("Terminal no encontrada"));

        if (!terminal.getBodega().getIdBodega().equals(idBodega)) {
            throw new SecurityException("No tienes permisos para revocar esta terminal");
        }

        terminal.setEstado(false);
        terminalRepository.save(terminal);
    }

    /**
     * Genera código de vinculación para el usuario actualmente autenticado (Dueño / Admin).
     */
    @Transactional
    public SolicitudCodigoVinculacionResponseDTO solicitarCodigoParaSesionActual() {
        Usuario admin = obtenerUsuarioEnSesion();
        if (admin == null || admin.getBodega() == null) {
            throw new AccessDeniedException("Debes tener una tienda asignada para generar códigos de vinculación de terminal");
        }
        return generarCodigoVinculacion(admin.getBodega().getIdBodega(), admin.getUsername());
    }

    /**
     * Lista las terminales para la tienda del usuario actualmente autenticado.
     */
    @Transactional(readOnly = true)
    public List<TerminalResponseDTO> listarTerminalesParaSesionActual() {
        Usuario admin = obtenerUsuarioEnSesion();
        if (admin == null || admin.getBodega() == null) {
            throw new AccessDeniedException("Debes tener una tienda asignada para consultar las terminales");
        }
        return listarTerminales(admin.getBodega().getIdBodega());
    }

    /**
     * Revoca una terminal para la tienda del usuario actualmente autenticado.
     */
    @Transactional
    public void revocarTerminalParaSesionActual(Long idTerminal) {
        Usuario admin = obtenerUsuarioEnSesion();
        if (admin == null || admin.getBodega() == null) {
            throw new AccessDeniedException("Debes tener una tienda asignada para gestionar terminales");
        }
        revocarTerminal(admin.getBodega().getIdBodega(), idTerminal);
    }

    private Usuario obtenerUsuarioEnSesion() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) {
            return usuarioRepository.findByUsernameIgnoreCase(auth.getName()).orElse(null);
        }
        return null;
    }

    private String UriUtils(String value) {
        if (value == null) return "";
        return java.net.URLEncoder.encode(value, java.nio.charset.StandardCharsets.UTF_8);
    }
}
