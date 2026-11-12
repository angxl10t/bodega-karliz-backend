package com.bodega.backend.service;

import com.bodega.backend.dto.ReclamacionCreacionDTO;
import com.bodega.backend.dto.ReclamacionDTO;
import com.bodega.backend.dto.ReclamacionRespuestaDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Reclamacion;
import com.bodega.backend.exception.ResourceNotFoundException;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.ReclamacionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.Year;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ReclamacionService {

    private final ReclamacionRepository reclamacionRepository;
    private final BodegaRepository bodegaRepository;
    private final TenantService tenantService;

    @Transactional
    public ReclamacionDTO registrarReclamacion(ReclamacionCreacionDTO dto) {
        Bodega bodega = null;
        if (dto.getIdBodega() != null) {
            bodega = bodegaRepository.findById(dto.getIdBodega()).orElse(null);
        }

        // Generar correlativo legal anual (ej: REC-2026-00001)
        long correlativo;
        try {
            correlativo = reclamacionRepository.obtenerSiguienteCorrelativo();
        } catch (Exception e) {
            log.warn("No se pudo obtener correlativo de la secuencia, usando fallback: {}", e.getMessage());
            correlativo = reclamacionRepository.count() + 1;
        }

        int anio = Year.now().getValue();
        String codigoReclamacion = String.format("REC-%d-%05d", anio, correlativo);

        String tipoNorm = "QUEJA".equalsIgnoreCase(dto.getTipo()) ? "QUEJA" : "RECLAMO";
        String tipoBienNorm = "SERVICIO".equalsIgnoreCase(dto.getTipoBien()) ? "SERVICIO" : "PRODUCTO";
        BigDecimal monto = dto.getMontoReclamado() != null ? dto.getMontoReclamado() : BigDecimal.ZERO;

        Reclamacion entity = Reclamacion.builder()
                .codigoReclamacion(codigoReclamacion)
                .bodega(bodega)
                .nombreReclamante(dto.getNombreReclamante().trim())
                .tipoDocumento(dto.getTipoDocumento().trim().toUpperCase())
                .numeroDocumento(dto.getNumeroDocumento().trim())
                .telefono(dto.getTelefono() != null ? dto.getTelefono().trim() : null)
                .email(dto.getEmail().trim().toLowerCase())
                .direccion(dto.getDireccion() != null ? dto.getDireccion().trim() : null)
                .tipo(tipoNorm)
                .tipoBien(tipoBienNorm)
                .montoReclamado(monto)
                .descripcionBien(dto.getDescripcionBien() != null ? dto.getDescripcionBien().trim() : null)
                .detalleReclamacion(dto.getDetalleReclamacion().trim())
                .pedidoReclamante(dto.getPedidoReclamante().trim())
                .estado("PENDIENTE")
                .build();

        Reclamacion guardada = reclamacionRepository.save(entity);
        log.info("Libro de Reclamaciones: Reclamación {} registrada por {} ({})",
                guardada.getCodigoReclamacion(), guardada.getNombreReclamante(), guardada.getTipo());

        return toDTO(guardada);
    }

    @Transactional(readOnly = true)
    public ReclamacionDTO consultarPorCodigo(String codigo) {
        return consultarPorCodigo(codigo, null);
    }

    @Transactional(readOnly = true)
    public ReclamacionDTO consultarPorCodigo(String codigo, String documento) {
        if (codigo == null || codigo.isBlank()) {
            throw new IllegalArgumentException("El código de reclamación no puede estar vacío");
        }
        Reclamacion r = reclamacionRepository.findByCodigoReclamacion(codigo.trim().toUpperCase())
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró ninguna reclamación con el código: " + codigo));

        boolean esAdmin = esUsuarioAdminOSuperAdmin();
        boolean docValido = documento != null && !documento.isBlank()
                && r.getNumeroDocumento() != null
                && r.getNumeroDocumento().trim().equalsIgnoreCase(documento.trim());

        if (esAdmin || docValido) {
            return toDTO(r);
        }

        return toMaskedDTO(r);
    }

    private boolean esUsuarioAdminOSuperAdmin() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getAuthorities() == null) return false;
        return auth.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equalsIgnoreCase("ROLE_ADMIN")
                        || a.getAuthority().equalsIgnoreCase("ADMIN")
                        || a.getAuthority().equalsIgnoreCase("ROLE_SUPERADMIN")
                        || a.getAuthority().equalsIgnoreCase("SUPERADMIN"));
    }

    private ReclamacionDTO toMaskedDTO(Reclamacion r) {
        ReclamacionDTO dto = toDTO(r);
        return ReclamacionDTO.builder()
                .idReclamacion(dto.getIdReclamacion())
                .codigoReclamacion(dto.getCodigoReclamacion())
                .idBodega(dto.getIdBodega())
                .nombreBodega(dto.getNombreBodega())
                .nombreReclamante(maskNombre(dto.getNombreReclamante()))
                .tipoDocumento(dto.getTipoDocumento())
                .numeroDocumento(maskDocumento(dto.getNumeroDocumento()))
                .telefono(maskTelefono(dto.getTelefono()))
                .email(maskEmail(dto.getEmail()))
                .direccion("Protegido por confidencialidad (Ley N° 29733)")
                .tipo(dto.getTipo())
                .tipoBien(dto.getTipoBien())
                .montoReclamado(dto.getMontoReclamado())
                .descripcionBien(dto.getDescripcionBien())
                .detalleReclamacion(maskDetalle(dto.getDetalleReclamacion()))
                .pedidoReclamante("Protegido por confidencialidad (Ley N° 29733)")
                .estado(dto.getEstado())
                .respuestaProveedor(dto.getRespuestaProveedor())
                .fechaReclamo(dto.getFechaReclamo())
                .fechaRespuesta(dto.getFechaRespuesta())
                .diasHabilesRestantes(dto.getDiasHabilesRestantes())
                .build();
    }

    private String maskNombre(String nombre) {
        if (nombre == null || nombre.isBlank()) return "";
        String[] partes = nombre.trim().split("\\s+");
        if (partes.length == 1) {
            return partes[0].substring(0, Math.min(2, partes[0].length())) + "***";
        }
        return partes[0] + " " + partes[1].substring(0, 1) + ".";
    }

    private String maskDocumento(String doc) {
        if (doc == null || doc.isBlank()) return "";
        String trimmed = doc.trim();
        if (trimmed.length() <= 4) return "****";
        return trimmed.substring(0, 2) + "****" + trimmed.substring(trimmed.length() - 2);
    }

    private String maskTelefono(String tel) {
        if (tel == null || tel.isBlank()) return "";
        String trimmed = tel.trim();
        if (trimmed.length() <= 4) return "****";
        return trimmed.substring(0, 3) + "***" + trimmed.substring(trimmed.length() - 2);
    }

    private String maskEmail(String email) {
        if (email == null || email.isBlank() || !email.contains("@")) return "";
        int atIdx = email.indexOf('@');
        String user = email.substring(0, atIdx);
        String domain = email.substring(atIdx);
        if (user.length() <= 2) return user.substring(0, 1) + "***" + domain;
        return user.substring(0, 1) + "***" + user.substring(user.length() - 1) + domain;
    }

    private String maskDetalle(String detalle) {
        if (detalle == null || detalle.isBlank()) return "";
        String trimmed = detalle.trim();
        if (trimmed.length() <= 25) return "Reclamación registrada (" + trimmed.length() + " caracteres)";
        return trimmed.substring(0, 25) + "... [Contenido reservado por privacidad]";
    }

    @Transactional(readOnly = true)
    public List<ReclamacionDTO> listarReclamaciones() {
        boolean esSuperadmin = esUsuarioSuperAdmin();
        if (esSuperadmin) {
            return reclamacionRepository.findTop200ByOrderByFechaReclamoDesc().stream()
                    .map(this::toDTO)
                    .collect(Collectors.toList());
        }

        Long currentBodegaId = tenantService.getCurrentBodegaId();
        return reclamacionRepository.findTop200ByBodega_IdBodegaOrderByFechaReclamoDesc(currentBodegaId).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public ReclamacionDTO responderReclamacion(Long idReclamacion, ReclamacionRespuestaDTO dto) {
        Reclamacion r = reclamacionRepository.findById(idReclamacion)
                .orElseThrow(() -> new ResourceNotFoundException("Reclamación no encontrada con ID: " + idReclamacion));

        boolean esSuperadmin = esUsuarioSuperAdmin();
        Long currentBodegaId = tenantService.getCurrentBodegaId();

        if (!esSuperadmin && (r.getBodega() == null || !r.getBodega().getIdBodega().equals(currentBodegaId))) {
            throw new AccessDeniedException("No tienes permisos para responder a esta reclamación");
        }

        r.setRespuestaProveedor(dto.getRespuestaProveedor().trim());
        String nuevoEstado = dto.getNuevoEstado() != null && !dto.getNuevoEstado().isBlank()
                ? dto.getNuevoEstado().trim().toUpperCase()
                : "ATENDIDO";
        r.setEstado(nuevoEstado);
        r.setFechaRespuesta(OffsetDateTime.now());

        Reclamacion guardada = reclamacionRepository.save(r);
        log.info("Reclamación {} respondida exitosamente con estado {}", guardada.getCodigoReclamacion(), nuevoEstado);
        return toDTO(guardada);
    }

    private boolean esUsuarioSuperAdmin() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getAuthorities() == null) return false;
        return auth.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equalsIgnoreCase("ROLE_SUPERADMIN") || a.getAuthority().equalsIgnoreCase("SUPERADMIN"));
    }

    private ReclamacionDTO toDTO(Reclamacion r) {
        int diasHabilesRestantes = calcularDiasHabilesRestantes(r.getFechaReclamo(), r.getFechaRespuesta());
        return ReclamacionDTO.builder()
                .idReclamacion(r.getIdReclamacion())
                .codigoReclamacion(r.getCodigoReclamacion())
                .idBodega(r.getBodega() != null ? r.getBodega().getIdBodega() : null)
                .nombreBodega(r.getBodega() != null ? r.getBodega().getNombreComercial() : "CajaYa Cloud POS (Plataforma)")
                .nombreReclamante(r.getNombreReclamante())
                .tipoDocumento(r.getTipoDocumento())
                .numeroDocumento(r.getNumeroDocumento())
                .telefono(r.getTelefono())
                .email(r.getEmail())
                .direccion(r.getDireccion())
                .tipo(r.getTipo())
                .tipoBien(r.getTipoBien())
                .montoReclamado(r.getMontoReclamado())
                .descripcionBien(r.getDescripcionBien())
                .detalleReclamacion(r.getDetalleReclamacion())
                .pedidoReclamante(r.getPedidoReclamante())
                .estado(r.getEstado())
                .respuestaProveedor(r.getRespuestaProveedor())
                .fechaReclamo(r.getFechaReclamo())
                .fechaRespuesta(r.getFechaRespuesta())
                .diasHabilesRestantes(diasHabilesRestantes)
                .build();
    }

    /**
     * Calcula los días hábiles restantes (lunes a viernes) respecto al plazo legal
     * perentorio de 15 días hábiles establecido por el Código de Protección y Defensa del Consumidor (Ley N° 29571).
     */
    private int calcularDiasHabilesRestantes(OffsetDateTime fechaReclamo, OffsetDateTime fechaRespuesta) {
        if (fechaRespuesta != null) {
            return 0;
        }
        if (fechaReclamo == null) {
            return 15;
        }

        LocalDate inicio = fechaReclamo.toLocalDate();
        LocalDate fin = LocalDate.now();

        if (fin.isBefore(inicio)) {
            return 15;
        }

        int diasHabilesTranscurridos = 0;
        LocalDate cursor = inicio.plusDays(1);
        while (!cursor.isAfter(fin)) {
            DayOfWeek dow = cursor.getDayOfWeek();
            if (dow != DayOfWeek.SATURDAY && dow != DayOfWeek.SUNDAY) {
                diasHabilesTranscurridos++;
            }
            cursor = cursor.plusDays(1);
        }

        int restantes = 15 - diasHabilesTranscurridos;
        return Math.max(0, restantes);
    }
}
