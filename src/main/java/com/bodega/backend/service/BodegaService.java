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

    public BodegaService(BodegaRepository bodegaRepository,
                         TenantService tenantService,
                         UserSecurityCacheService userSecurityCacheService) {
        this.bodegaRepository = bodegaRepository;
        this.tenantService = tenantService;
        this.userSecurityCacheService = userSecurityCacheService;
    }

    @Transactional(readOnly = true)
    public BodegaDTO obtenerMiBodega() {
        Bodega bodega = tenantService.getCurrentBodega();
        return mapToDTO(bodega);
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
        return dto;
    }
}
