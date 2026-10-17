package com.bodega.backend.service;

import com.bodega.backend.dto.ActualizarBodegaDTO;
import com.bodega.backend.dto.BodegaDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.security.UserSecurityCacheService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BodegaService {

    private final BodegaRepository bodegaRepository;
    private final TenantService tenantService;
    private final UserSecurityCacheService userSecurityCacheService;
    private final com.bodega.backend.repository.PagoSuscripcionRepository pagoSuscripcionRepository;

    public BodegaService(BodegaRepository bodegaRepository,
                         TenantService tenantService,
                         UserSecurityCacheService userSecurityCacheService,
                         com.bodega.backend.repository.PagoSuscripcionRepository pagoSuscripcionRepository) {
        this.bodegaRepository = bodegaRepository;
        this.tenantService = tenantService;
        this.userSecurityCacheService = userSecurityCacheService;
        this.pagoSuscripcionRepository = pagoSuscripcionRepository;
    }

    @Transactional(readOnly = true)
    public BodegaDTO obtenerMiBodega() {
        Bodega bodega = tenantService.getCurrentBodega();
        return mapToDTO(bodega);
    }

    @Transactional(readOnly = true)
    public java.util.List<BodegaDTO> listarTodas() {
        return bodegaRepository.findAll(org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Direction.ASC, "idBodega"))
                .stream()
                .map(this::mapToDTO)
                .collect(java.util.stream.Collectors.toList());
    }

    @Transactional(readOnly = true)
    public BodegaDTO obtenerPorId(Long idBodega) {
        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        boolean isSuperAdmin = auth != null && auth.getAuthorities() != null && 
                auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_SUPERADMIN"));
        if (!isSuperAdmin) {
            Long currentBodegaId = tenantService.getCurrentBodegaId();
            if (currentBodegaId == null || !currentBodegaId.equals(idBodega)) {
                throw new org.springframework.security.access.AccessDeniedException(
                        "No tienes permisos para ver información de otra bodega."
                );
            }
        }
        Bodega b = bodegaRepository.findById(idBodega)
                .orElseThrow(() -> new RuntimeException("Bodega con ID " + idBodega + " no encontrada"));
        return mapToDTO(b);
    }

    @Transactional
    public BodegaDTO actualizarConfiguracion(ActualizarBodegaDTO dto) {
        Bodega bodega = tenantService.getCurrentBodega();

        // Nivel 1: Identidad básica comercial
        if (dto.getNombreComercial() != null && !dto.getNombreComercial().isBlank()) {
            bodega.setNombreComercial(dto.getNombreComercial().trim());
        }
        bodega.setRucDni(dto.getRucDni() != null && !dto.getRucDni().isBlank() ? dto.getRucDni().trim() : null);
        bodega.setDireccion(dto.getDireccion() != null && !dto.getDireccion().isBlank() ? dto.getDireccion().trim() : null);
        bodega.setTelefono(dto.getTelefono() != null && !dto.getTelefono().isBlank() ? dto.getTelefono().trim() : null);
        bodega.setLemaComercial(dto.getLemaComercial() != null && !dto.getLemaComercial().isBlank() ? dto.getLemaComercial().trim() : null);

        String plan = (bodega.getPlan() != null) ? bodega.getPlan().toUpperCase() : "BASICO";

        // Nivel 2: Paleta de acento & Branding (Exclusivo Plan PRO)
        if (dto.getColorPrimario() != null && !dto.getColorPrimario().isBlank()) {
            String nuevoColor = dto.getColorPrimario().trim();
            // Si el color es diferente al azul por defecto de CajaYa (#2563EB) y no es Plan PRO
            boolean esDefault = "#2563EB".equalsIgnoreCase(nuevoColor);
            if (!esDefault && !"PRO".equalsIgnoreCase(plan)) {
                throw new RuntimeException("La personalización exclusiva de paleta de colores requiere el Plan Minimarket Pro. " +
                        "En el Plan Bodega se utiliza la paleta estándar de CajaYa.");
            }
            bodega.setColorPrimario(nuevoColor);
        }

        if (dto.getLogoUrl() != null && !dto.getLogoUrl().isBlank()) {
            if (!"PRO".equalsIgnoreCase(plan)) {
                throw new RuntimeException("La incorporación de logotipo personalizado en comprobantes y pantalla requiere el Plan Minimarket Pro.");
            }
            bodega.setLogoUrl(dto.getLogoUrl().trim());
        } else if (dto.getLogoUrl() != null && dto.getLogoUrl().isBlank()) {
            bodega.setLogoUrl(null);
        }

        Bodega guardada = bodegaRepository.save(bodega);
        // Invalidar caché de perfiles para que todos los usuarios de la bodega reflejen la nueva configuración de inmediato
        userSecurityCacheService.evictAll();

        return mapToDTO(guardada);
    }

    /**
     * Solución 1: Renovación Directa de Suscripción vía Yape / Plin (0% Comisiones)
     */
    @Transactional
    public BodegaDTO registrarPagoYape(com.bodega.backend.dto.PagoYapeDTO dto) {
        Bodega bodega = tenantService.getCurrentBodega();

        String codOp = dto.getCodigoOperacion() != null ? dto.getCodigoOperacion().trim() : "";
        String billetera = dto.getBilletera() != null ? dto.getBilletera().trim().toUpperCase() : "YAPE";

        // Blindaje Anti-Fraude: Prevención estricta de vouchers/códigos de operación reutilizados
        if (pagoSuscripcionRepository.existsByBilleteraIgnoreCaseAndCodigoOperacion(billetera, codOp)) {
            throw new RuntimeException("El código de operación '" + codOp + "' de " + billetera + 
                    " ya fue registrado y procesado previamente. Los comprobantes de pago no pueden reutilizarse.");
        }

        // Validar coherencia de montos oficiales
        String planSolicitado = dto.getPlan().trim().toUpperCase();
        java.math.BigDecimal montoEsperado = "PRO".equals(planSolicitado) 
                ? new java.math.BigDecimal("100.00") 
                : new java.math.BigDecimal("50.00");

        if (dto.getMonto().compareTo(montoEsperado) < 0) {
            throw new RuntimeException("El monto enviado (S/ " + dto.getMonto() + 
                    ") es inferior a la tarifa oficial del Plan " + planSolicitado + " (S/ " + montoEsperado + ").");
        }

        // Extensión acumulativa: Si el plan aún está vigente, suma 30 días al vencimiento actual; si no, 30 días desde hoy
        java.time.OffsetDateTime baseTime = (bodega.getFechaVencimientoPlan() != null && bodega.getFechaVencimientoPlan().isAfter(java.time.OffsetDateTime.now()))
                ? bodega.getFechaVencimientoPlan()
                : java.time.OffsetDateTime.now();

        bodega.setFechaVencimientoPlan(baseTime.plusDays(30));
        bodega.setPlan(planSolicitado);
        bodega.setEstado(true);

        Bodega guardada = bodegaRepository.save(bodega);

        // Registro de Auditoría en Libro Mayor de Suscripciones (Zero Data Loss)
        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        String usuarioActual = (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) 
                ? auth.getName() : "ADMIN";

        com.bodega.backend.entity.PagoSuscripcion pago = new com.bodega.backend.entity.PagoSuscripcion();
        pago.setBodega(guardada);
        pago.setCodigoOperacion(codOp);
        pago.setBilletera(billetera);
        pago.setPlan(planSolicitado);
        pago.setMonto(dto.getMonto());
        pago.setUsuarioRegistro(usuarioActual);
        pago.setEstado("CONFIRMADO");
        pagoSuscripcionRepository.save(pago);

        userSecurityCacheService.evictAll();

        return mapToDTO(guardada);
    }

    /**
     * Solución 2: Activación y Configuración del Módulo SUNAT
     * REGLA DE SEGURIDAD ESTRICTA: Solo el Administrador de la bodega puede activar,
     * desactivar o configurar credenciales de facturación. Los cajeros tienen acceso denegado.
     */
    @Transactional
    public BodegaDTO actualizarConfiguracionSunat(com.bodega.backend.dto.ConfiguracionSunatDTO dto) {
        // Validación de Rol en Contexto de Seguridad
        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        boolean esAdmin = auth != null && auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));

        if (!esAdmin) {
            throw new RuntimeException("Acceso Denegado: Solo el Administrador de la bodega puede activar o modificar la Facturación Electrónica SUNAT. Los cajeros no tienen permisos para alterar este módulo.");
        }

        Bodega bodega = tenantService.getCurrentBodega();

        if (dto.getFacturacionSunatActiva() != null) {
            bodega.setFacturacionSunatActiva(dto.getFacturacionSunatActiva());
        }

        if (dto.getSunatProveedor() != null && !dto.getSunatProveedor().isBlank()) {
            bodega.setSunatProveedor(dto.getSunatProveedor().trim());
        }

        if (dto.getSunatRucEmisor() != null) {
            bodega.setSunatRucEmisor(dto.getSunatRucEmisor().isBlank() ? null : dto.getSunatRucEmisor().trim());
        }

        if (dto.getSunatUsuarioSol() != null) {
            bodega.setSunatUsuarioSol(dto.getSunatUsuarioSol().isBlank() ? null : dto.getSunatUsuarioSol().trim());
        }

        if (dto.getSunatTokenApi() != null && !dto.getSunatTokenApi().isBlank()) {
            bodega.setSunatTokenApi(dto.getSunatTokenApi().trim());
        }

        if (dto.getSerieBoleta() != null && !dto.getSerieBoleta().isBlank()) {
            bodega.setSerieBoleta(dto.getSerieBoleta().trim().toUpperCase());
        }

        if (dto.getSerieFactura() != null && !dto.getSerieFactura().isBlank()) {
            bodega.setSerieFactura(dto.getSerieFactura().trim().toUpperCase());
        }

        Bodega guardada = bodegaRepository.save(bodega);
        userSecurityCacheService.evictAll();

        return mapToDTO(guardada);
    }

    private BodegaDTO mapToDTO(Bodega b) {
        BodegaDTO dto = new BodegaDTO();
        dto.setIdBodega(b.getIdBodega());
        dto.setNombreComercial(b.getNombreComercial());
        dto.setRucDni(b.getRucDni());
        dto.setDireccion(b.getDireccion());
        dto.setTelefono(b.getTelefono());
        dto.setLogoUrl(b.getLogoUrl());
        dto.setColorPrimario(b.getColorPrimario() != null ? b.getColorPrimario() : "#2563EB");
        dto.setLemaComercial(b.getLemaComercial());
        dto.setPlan(b.getPlan());
        dto.setEstado(b.getEstado());
        dto.setFechaRegistro(b.getFechaRegistro());
        dto.setFechaVencimientoPlan(b.getFechaVencimientoPlan());

        // Campos Módulo SUNAT
        dto.setFacturacionSunatActiva(Boolean.TRUE.equals(b.getFacturacionSunatActiva()));
        dto.setSunatProveedor(b.getSunatProveedor());
        dto.setSunatRucEmisor(b.getSunatRucEmisor());
        dto.setSunatUsuarioSol(b.getSunatUsuarioSol());
        dto.setSerieBoleta(b.getSerieBoleta());
        dto.setSerieFactura(b.getSerieFactura());
        dto.setUltimoCorrelativoBoleta(b.getUltimoCorrelativoBoleta());
        dto.setUltimoCorrelativoFactura(b.getUltimoCorrelativoFactura());
        return dto;
    }

    @Transactional(readOnly = true)
    public java.util.List<com.bodega.backend.dto.PagoSuscripcionDTO> listarMisPagos() {
        Bodega bodega = tenantService.getCurrentBodega();
        return pagoSuscripcionRepository.findByBodega_IdBodegaOrderByFechaPagoDesc(bodega.getIdBodega())
                .stream()
                .map(this::mapPagoToDTO)
                .collect(java.util.stream.Collectors.toList());
    }

    @Transactional(readOnly = true)
    public java.util.List<com.bodega.backend.dto.PagoSuscripcionDTO> listarTodosLosPagos() {
        return pagoSuscripcionRepository.findAllByOrderByFechaPagoDesc()
                .stream()
                .map(this::mapPagoToDTO)
                .collect(java.util.stream.Collectors.toList());
    }

    private com.bodega.backend.dto.PagoSuscripcionDTO mapPagoToDTO(com.bodega.backend.entity.PagoSuscripcion p) {
        com.bodega.backend.dto.PagoSuscripcionDTO dto = new com.bodega.backend.dto.PagoSuscripcionDTO();
        dto.setIdPago(p.getIdPago());
        if (p.getBodega() != null) {
            dto.setIdBodega(p.getBodega().getIdBodega());
            dto.setNombreBodega(p.getBodega().getNombreComercial());
        }
        dto.setCodigoOperacion(p.getCodigoOperacion());
        dto.setBilletera(p.getBilletera());
        dto.setPlan(p.getPlan());
        dto.setMonto(p.getMonto());
        dto.setFechaPago(p.getFechaPago());
        dto.setUsuarioRegistro(p.getUsuarioRegistro());
        dto.setEstado(p.getEstado());
        return dto;
    }
}
