package com.bodega.backend.service;

import com.bodega.backend.dto.UsuarioDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.UsuarioRepository;
import com.bodega.backend.security.UserSecurityCacheService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class UsuarioServiceTest {

    @Mock
    private UsuarioRepository usuarioRepository;

    @Mock
    private BodegaRepository bodegaRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private UserSecurityCacheService userSecurityCacheService;

    @InjectMocks
    private UsuarioService usuarioService;

    private Bodega bodega1;

    @BeforeEach
    void setUp() {
        bodega1 = new Bodega();
        bodega1.setIdBodega(1L);
        bodega1.setNombreComercial("Bodega KARLIZ");
        bodega1.setPlan("PRO");
    }

    @Test
    void testCrearCajero_Exitoso() {
        UsuarioDTO dto = new UsuarioDTO();
        dto.setUsername("cajero_juan");
        dto.setPassword("claveSegura123");
        dto.setRol("CAJERO");

        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodega1));
        when(usuarioRepository.findByUsernameIgnoreCase("cajero_juan")).thenReturn(Optional.empty());
        when(passwordEncoder.encode("claveSegura123")).thenReturn("encodedPassword");

        Usuario guardado = new Usuario();
        guardado.setIdUsuario(10L);
        guardado.setUsername("cajero_juan");
        guardado.setPassword("encodedPassword");
        guardado.setRol("CAJERO");
        guardado.setEstado(true);
        guardado.setBodega(bodega1);

        when(usuarioRepository.save(any(Usuario.class))).thenReturn(guardado);

        UsuarioDTO resultado = usuarioService.crearUsuario(dto);

        assertNotNull(resultado);
        assertEquals("cajero_juan", resultado.getUsername());
        assertEquals("CAJERO", resultado.getRol());
        assertTrue(resultado.getEstado());
        verify(usuarioRepository, times(1)).save(any(Usuario.class));
    }

    @Test
    void testMismoCajero_MismaBodega_Activo_LanzaErrorInformativo() {
        UsuarioDTO dto = new UsuarioDTO();
        dto.setUsername("cajero_juan");
        dto.setPassword("claveSegura123");
        dto.setRol("CAJERO");

        Usuario existenteActivo = new Usuario();
        existenteActivo.setIdUsuario(10L);
        existenteActivo.setUsername("cajero_juan");
        existenteActivo.setEstado(true);
        existenteActivo.setBodega(bodega1);

        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodega1));
        when(usuarioRepository.findByUsernameIgnoreCase("cajero_juan")).thenReturn(Optional.of(existenteActivo));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> usuarioService.crearUsuario(dto));

        assertTrue(ex.getMessage().contains("ya está registrado y activo en tu bodega"));
        verify(usuarioRepository, never()).save(any());
    }

    @Test
    void testMismoCajero_MismaBodega_Inactivo_ReactivaExitosamente() {
        UsuarioDTO dto = new UsuarioDTO();
        dto.setUsername("cajero_juan");
        dto.setPassword("nuevaClave2026");
        dto.setRol("CAJERO");

        Usuario existenteInactivo = new Usuario();
        existenteInactivo.setIdUsuario(10L);
        existenteInactivo.setUsername("cajero_juan");
        existenteInactivo.setEstado(false);
        existenteInactivo.setBodega(bodega1);

        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodega1));
        when(usuarioRepository.findByUsernameIgnoreCase("cajero_juan")).thenReturn(Optional.of(existenteInactivo));
        when(passwordEncoder.encode("nuevaClave2026")).thenReturn("newEncodedPassword");
        when(usuarioRepository.save(existenteInactivo)).thenReturn(existenteInactivo);

        UsuarioDTO resultado = usuarioService.crearUsuario(dto);

        assertNotNull(resultado);
        assertEquals("cajero_juan", resultado.getUsername());
        assertTrue(resultado.getEstado());
        verify(usuarioRepository, times(1)).save(existenteInactivo);
        verify(userSecurityCacheService, times(1)).evict("cajero_juan");
    }

    @Test
    void testMismoCajero_OtraBodega_ColisionMultiTenant_SugiereNombres() {
        UsuarioDTO dto = new UsuarioDTO();
        dto.setUsername("cajero1");
        dto.setPassword("claveSegura123");
        dto.setRol("CAJERO");

        Bodega otraBodega = new Bodega();
        otraBodega.setIdBodega(99L);
        otraBodega.setNombreComercial("Otra Tienda");

        Usuario existenteOtraBodega = new Usuario();
        existenteOtraBodega.setIdUsuario(50L);
        existenteOtraBodega.setUsername("cajero1");
        existenteOtraBodega.setEstado(true);
        existenteOtraBodega.setBodega(otraBodega);

        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodega1));
        when(usuarioRepository.findByUsernameIgnoreCase("cajero1")).thenReturn(Optional.of(existenteOtraBodega));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> usuarioService.crearUsuario(dto));

        assertTrue(ex.getMessage().contains("ya está en uso por otra tienda"));
        assertTrue(ex.getMessage().contains("Te sugerimos usar:"));
        verify(usuarioRepository, never()).save(any());
    }

    @Test
    void testValidacionCaracteresUsuarioInvalido() {
        UsuarioDTO dto = new UsuarioDTO();
        dto.setUsername("cajero con espacios");
        dto.setPassword("claveSegura123");
        dto.setRol("CAJERO");

        RuntimeException ex = assertThrows(RuntimeException.class, () -> usuarioService.crearUsuario(dto));
        assertTrue(ex.getMessage().contains("solo puede contener letras, números"));
    }

    @Test
    void testCrearCajero_ConPinDe4Digitos_Exitoso() {
        UsuarioDTO dto = new UsuarioDTO();
        dto.setUsername("cajero_pin");
        dto.setPassword("1234");
        dto.setRol("CAJERO");

        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodega1));
        when(usuarioRepository.findByUsernameIgnoreCase("cajero_pin")).thenReturn(Optional.empty());
        when(passwordEncoder.encode("1234")).thenReturn("encodedPin1234");

        Usuario guardado = new Usuario();
        guardado.setIdUsuario(20L);
        guardado.setUsername("cajero_pin");
        guardado.setPassword("encodedPin1234");
        guardado.setRol("CAJERO");
        guardado.setEstado(true);
        guardado.setBodega(bodega1);

        when(usuarioRepository.save(any(Usuario.class))).thenReturn(guardado);

        UsuarioDTO resultado = usuarioService.crearUsuario(dto);

        assertNotNull(resultado);
        assertEquals("cajero_pin", resultado.getUsername());
        assertEquals("CAJERO", resultado.getRol());
        verify(passwordEncoder, times(1)).encode("1234");
    }

    @Test
    void testCrearCajero_ConClaveMenorA4Digitos_LanzaError() {
        UsuarioDTO dto = new UsuarioDTO();
        dto.setUsername("cajero_corto");
        dto.setPassword("123"); // 3 dígitos < 4
        dto.setRol("CAJERO");

        RuntimeException ex = assertThrows(RuntimeException.class, () -> usuarioService.crearUsuario(dto));
        assertTrue(ex.getMessage().contains("entre 4 y 72 caracteres"));
        verify(usuarioRepository, never()).save(any());
    }

    @Test
    void testCambiarEstado_OtraBodega_LanzaAccessDeniedException() {
        Bodega bodega2 = new Bodega();
        bodega2.setIdBodega(2L);

        Usuario targetOtraBodega = new Usuario();
        targetOtraBodega.setIdUsuario(99L);
        targetOtraBodega.setUsername("cajero_otra_tienda");
        targetOtraBodega.setRol("CAJERO");
        targetOtraBodega.setBodega(bodega2);

        when(usuarioRepository.findById(99L)).thenReturn(Optional.of(targetOtraBodega));

        // Simular sesión autenticada como admin de bodega 1
        Usuario adminSesion = new Usuario();
        adminSesion.setUsername("admin_bodega1");
        adminSesion.setRol("ADMIN");
        adminSesion.setBodega(bodega1);

        org.springframework.security.core.Authentication auth = mock(org.springframework.security.core.Authentication.class);
        when(auth.isAuthenticated()).thenReturn(true);
        when(auth.getName()).thenReturn("admin_bodega1");
        org.springframework.security.core.context.SecurityContextHolder.getContext().setAuthentication(auth);
        when(usuarioRepository.findByUsernameIgnoreCase("admin_bodega1")).thenReturn(Optional.of(adminSesion));

        assertThrows(org.springframework.security.access.AccessDeniedException.class, () -> {
            usuarioService.cambiarEstado(99L, false, "admin_bodega1");
        });

        verify(usuarioRepository, never()).save(targetOtraBodega);
        org.springframework.security.core.context.SecurityContextHolder.clearContext();
    }

    @Test
    void testCambiarEstado_TargetSuperAdmin_PorAdminNormal_LanzaAccessDeniedException() {
        Usuario targetSuperAdmin = new Usuario();
        targetSuperAdmin.setIdUsuario(100L);
        targetSuperAdmin.setUsername("super_global");
        targetSuperAdmin.setRol("SUPERADMIN");
        targetSuperAdmin.setBodega(null);

        when(usuarioRepository.findById(100L)).thenReturn(Optional.of(targetSuperAdmin));

        Usuario adminSesion = new Usuario();
        adminSesion.setUsername("admin_bodega1");
        adminSesion.setRol("ADMIN");
        adminSesion.setBodega(bodega1);

        org.springframework.security.core.Authentication auth = mock(org.springframework.security.core.Authentication.class);
        when(auth.isAuthenticated()).thenReturn(true);
        when(auth.getName()).thenReturn("admin_bodega1");
        org.springframework.security.core.context.SecurityContextHolder.getContext().setAuthentication(auth);
        when(usuarioRepository.findByUsernameIgnoreCase("admin_bodega1")).thenReturn(Optional.of(adminSesion));

        assertThrows(org.springframework.security.access.AccessDeniedException.class, () -> {
            usuarioService.cambiarEstado(100L, false, "admin_bodega1");
        });

        verify(usuarioRepository, never()).save(targetSuperAdmin);
        org.springframework.security.core.context.SecurityContextHolder.clearContext();
    }
}
