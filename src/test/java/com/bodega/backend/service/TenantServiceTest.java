package com.bodega.backend.service;

import com.bodega.backend.entity.Bodega;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.security.UserSecurityCacheService;
import com.bodega.backend.security.UserSecurityProfile;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class TenantServiceTest {

    @Mock
    private UserSecurityCacheService userSecurityCacheService;

    @Mock
    private BodegaRepository bodegaRepository;

    @InjectMocks
    private TenantService tenantService;

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void testGetCurrentBodegaId_UsuarioAutenticado_RetornaIdDeBodega() {
        var auth = new UsernamePasswordAuthenticationToken(
                "cajero1", "pass", List.of(new SimpleGrantedAuthority("ROLE_CAJERO")));
        SecurityContextHolder.getContext().setAuthentication(auth);

        UserSecurityProfile profile = new UserSecurityProfile(
                "cajero1", "hash", "CAJERO", true, OffsetDateTime.now(),
                5L, "Bodega Las Palmas", "PRO", "#2563EB", null, null
        );
        when(userSecurityCacheService.getSecurityProfile("cajero1")).thenReturn(Optional.of(profile));

        Long idBodega = tenantService.getCurrentBodegaId();

        assertEquals(5L, idBodega);
        verify(bodegaRepository, never()).findFirstByOrderByIdBodegaAsc();
    }

    @Test
    void testGetCurrentBodegaId_SuperAdminSinBodega_ResuelvePrimeraBodega() {
        var auth = new UsernamePasswordAuthenticationToken(
                "superadmin", "pass", List.of(new SimpleGrantedAuthority("ROLE_SUPERADMIN")));
        SecurityContextHolder.getContext().setAuthentication(auth);

        UserSecurityProfile profile = new UserSecurityProfile(
                "superadmin", "hash", "SUPERADMIN", true, OffsetDateTime.now(),
                null, "CajaYa Platform", "SUPERADMIN", "#8B5CF6", null, null
        );
        when(userSecurityCacheService.getSecurityProfile("superadmin")).thenReturn(Optional.of(profile));

        Bodega primera = new Bodega();
        primera.setIdBodega(10L);
        when(bodegaRepository.findFirstByOrderByIdBodegaAsc()).thenReturn(Optional.of(primera));

        Long idBodega = tenantService.getCurrentBodegaId();

        assertEquals(10L, idBodega);
    }

    @Test
    void testGetCurrentBodegaId_SinSesion_UsaFallbackOptimizador() {
        Bodega primera = new Bodega();
        primera.setIdBodega(1L);
        when(bodegaRepository.findFirstByOrderByIdBodegaAsc()).thenReturn(Optional.of(primera));

        Long idBodega = tenantService.getCurrentBodegaId();

        assertEquals(1L, idBodega);
        verify(bodegaRepository, times(1)).findFirstByOrderByIdBodegaAsc();
    }

    @Test
    void testGetCurrentBodega_ExistePorId_RetornaEntidad() {
        Bodega b = new Bodega();
        b.setIdBodega(1L);
        b.setNombreComercial("Bodega Central");

        when(bodegaRepository.findFirstByOrderByIdBodegaAsc()).thenReturn(Optional.of(b));
        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(b));

        Bodega resultado = tenantService.getCurrentBodega();

        assertNotNull(resultado);
        assertEquals("Bodega Central", resultado.getNombreComercial());
    }

    @Test
    void testGetCurrentBodega_NoExisteNinguna_LanzaExcepcion() {
        when(bodegaRepository.findFirstByOrderByIdBodegaAsc()).thenReturn(Optional.empty());
        when(bodegaRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> tenantService.getCurrentBodega());
    }
}
