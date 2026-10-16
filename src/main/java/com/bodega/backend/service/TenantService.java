package com.bodega.backend.service;

import com.bodega.backend.entity.Bodega;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.security.UserSecurityCacheService;
import com.bodega.backend.security.UserSecurityProfile;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.util.Optional;

/**
 * Servicio centralizado para la resolución segura del inquilino (Tenant/Bodega)
 * en el contexto de ejecución actual.
 */
@Service
public class TenantService {

    private final UserSecurityCacheService userSecurityCacheService;
    private final BodegaRepository bodegaRepository;

    public TenantService(UserSecurityCacheService userSecurityCacheService,
                         BodegaRepository bodegaRepository) {
        this.userSecurityCacheService = userSecurityCacheService;
        this.bodegaRepository = bodegaRepository;
    }

    /**
     * Obtiene el ID de la bodega del usuario autenticado en la sesión.
     * Si no hay sesión (ej. ejecuciones internas o tests), se asume Tenant 1 (Bodega KARLIZ).
     */
    public Long getCurrentBodegaId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) {
            Optional<UserSecurityProfile> profile = userSecurityCacheService.getSecurityProfile(auth.getName());
            if (profile.isPresent() && profile.get().getIdBodega() != null) {
                return profile.get().getIdBodega();
            }
        }
        return 1L; // Fallback por defecto seguro: Tenant 1 (Bodega KARLIZ)
    }

    /**
     * Obtiene la entidad Bodega correspondiente al inquilino autenticado.
     */
    public Bodega getCurrentBodega() {
        Long idBodega = getCurrentBodegaId();
        return bodegaRepository.findById(idBodega)
                .orElseGet(() -> bodegaRepository.findById(1L)
                        .orElseThrow(() -> new RuntimeException("Bodega no configurada en el sistema")));
    }
}
