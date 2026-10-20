package com.bodega.backend.security;

import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import java.io.IOException;
import java.time.OffsetDateTime;
import java.util.Date;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class JwtAuthenticationFilterTest {

    @Mock
    private JwtUtil jwtUtil;

    @Mock
    private UserSecurityCacheService userSecurityCacheService;

    @Mock
    private HttpServletRequest request;

    @Mock
    private HttpServletResponse response;

    @Mock
    private FilterChain filterChain;

    @Mock
    private Claims claims;

    private JwtAuthenticationFilter filter;

    @BeforeEach
    void setUp() {
        SecurityContextHolder.clearContext();
        filter = new JwtAuthenticationFilter(jwtUtil, userSecurityCacheService);
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    @DisplayName("Debe autenticar correctamente con token Bearer válido, usuario activo y bodega activa")
    void testAutenticacionExitosa() throws ServletException, IOException {
        String token = "valid.jwt.token";
        when(request.getHeader("Authorization")).thenReturn("Bearer " + token);
        when(jwtUtil.extractAllClaims(token)).thenReturn(claims);
        when(claims.getSubject()).thenReturn("cajero1");
        when(claims.getIssuedAt()).thenReturn(new Date(System.currentTimeMillis()));

        UserSecurityProfile profile = new UserSecurityProfile(
                "cajero1", "hashedPass", "CAJERO", true, null,
                1L, "Bodega Test", "PRO", "#2563EB", null, null, true
        );
        when(userSecurityCacheService.getSecurityProfile("cajero1")).thenReturn(Optional.of(profile));

        filter.doFilterInternal(request, response, filterChain);

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        assertNotNull(auth, "La autenticación debe establecerse en el SecurityContext");
        assertEquals("cajero1", auth.getName());
        assertTrue(auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_CAJERO")));
        verify(filterChain).doFilter(request, response);
    }

    @Test
    @DisplayName("Sin header Authorization debe continuar la cadena sin autenticar")
    void testSinHeaderAuthorization() throws ServletException, IOException {
        when(request.getHeader("Authorization")).thenReturn(null);

        filter.doFilterInternal(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(filterChain).doFilter(request, response);
        verifyNoInteractions(jwtUtil, userSecurityCacheService);
    }

    @Test
    @DisplayName("Header sin prefijo Bearer debe continuar la cadena sin autenticar")
    void testHeaderSinBearer() throws ServletException, IOException {
        when(request.getHeader("Authorization")).thenReturn("Basic dXNlcjpwYXNz");

        filter.doFilterInternal(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(filterChain).doFilter(request, response);
        verifyNoInteractions(jwtUtil, userSecurityCacheService);
    }

    @Test
    @DisplayName("Token JWT inválido o con firma alterada no debe autenticar")
    void testTokenInvalido() throws ServletException, IOException {
        String token = "malformed.or.expired.jwt";
        when(request.getHeader("Authorization")).thenReturn("Bearer " + token);
        when(jwtUtil.extractAllClaims(token)).thenThrow(new RuntimeException("Signature invalid"));

        filter.doFilterInternal(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(filterChain).doFilter(request, response);
    }

    @Test
    @DisplayName("Usuario inactivo no debe ser autenticado")
    void testUsuarioInactivoRechazado() throws ServletException, IOException {
        String token = "valid.jwt.token";
        when(request.getHeader("Authorization")).thenReturn("Bearer " + token);
        when(jwtUtil.extractAllClaims(token)).thenReturn(claims);
        when(claims.getSubject()).thenReturn("usuario_bloqueado");

        UserSecurityProfile profile = new UserSecurityProfile(
                "usuario_bloqueado", "hashedPass", "CAJERO", false, null,
                1L, "Bodega Test", "PRO", "#2563EB", null, null, true
        );
        when(userSecurityCacheService.getSecurityProfile("usuario_bloqueado")).thenReturn(Optional.of(profile));

        filter.doFilterInternal(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(filterChain).doFilter(request, response);
    }

    @Test
    @DisplayName("Bodega inactiva rechaza acceso a cajeros y administradores regulares")
    void testBodegaInactivaRechazada() throws ServletException, IOException {
        String token = "valid.jwt.token";
        when(request.getHeader("Authorization")).thenReturn("Bearer " + token);
        when(jwtUtil.extractAllClaims(token)).thenReturn(claims);
        when(claims.getSubject()).thenReturn("admin1");

        UserSecurityProfile profile = new UserSecurityProfile(
                "admin1", "hashedPass", "ADMIN", true, null,
                1L, "Bodega Desactivada", "PRO", "#2563EB", null, null, false
        );
        when(userSecurityCacheService.getSecurityProfile("admin1")).thenReturn(Optional.of(profile));

        filter.doFilterInternal(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(filterChain).doFilter(request, response);
    }

    @Test
    @DisplayName("SUPERADMIN puede autenticarse incluso si el estado de bodega es false")
    void testSuperAdminPermitidoConBodegaInactiva() throws ServletException, IOException {
        String token = "valid.jwt.token";
        when(request.getHeader("Authorization")).thenReturn("Bearer " + token);
        when(jwtUtil.extractAllClaims(token)).thenReturn(claims);
        when(claims.getSubject()).thenReturn("superadmin");
        when(claims.getIssuedAt()).thenReturn(new Date(System.currentTimeMillis()));

        UserSecurityProfile profile = new UserSecurityProfile(
                "superadmin", "hashedPass", "SUPERADMIN", true, null,
                1L, "Plataforma Central", "PRO", "#2563EB", null, null, false
        );
        when(userSecurityCacheService.getSecurityProfile("superadmin")).thenReturn(Optional.of(profile));

        filter.doFilterInternal(request, response, filterChain);

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        assertNotNull(auth, "El SUPERADMIN debe autenticarse sin importar estado de bodega individual");
        assertTrue(auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_SUPERADMIN")));
        verify(filterChain).doFilter(request, response);
    }

    @Test
    @DisplayName("Token emitido antes del cambio de contraseña debe ser revocado")
    void testTokenRevocadoPorCambioDeClave() throws ServletException, IOException {
        String token = "valid.jwt.token";
        when(request.getHeader("Authorization")).thenReturn("Bearer " + token);
        when(jwtUtil.extractAllClaims(token)).thenReturn(claims);
        when(claims.getSubject()).thenReturn("cajero1");

        // Token emitido a las 10:00
        long emitidoMillis = System.currentTimeMillis() - 100000;
        when(claims.getIssuedAt()).thenReturn(new Date(emitidoMillis));

        // Clave cambiada a las 10:01
        OffsetDateTime cambioClave = OffsetDateTime.now();
        UserSecurityProfile profile = new UserSecurityProfile(
                "cajero1", "newHashedPass", "CAJERO", true, cambioClave,
                1L, "Bodega Test", "PRO", "#2563EB", null, null, true
        );
        when(userSecurityCacheService.getSecurityProfile("cajero1")).thenReturn(Optional.of(profile));

        filter.doFilterInternal(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication(), "El token anterior al cambio de clave debe ser rechazado");
        verify(filterChain).doFilter(request, response);
    }
}
