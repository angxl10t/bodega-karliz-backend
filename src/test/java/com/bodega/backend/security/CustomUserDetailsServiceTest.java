package com.bodega.backend.security;

import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.UsuarioRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class CustomUserDetailsServiceTest {

    @Mock
    private UsuarioRepository usuarioRepository;

    @InjectMocks
    private CustomUserDetailsService userDetailsService;

    @Test
    void testLoadUserByUsername_UsuarioActivoBodegaActiva_RetornaUserDetails() {
        Bodega bodega = new Bodega();
        bodega.setIdBodega(1L);
        bodega.setEstado(true);

        Usuario usuario = new Usuario();
        usuario.setUsername("cajero1");
        usuario.setPassword("hashedPass");
        usuario.setRol("CAJERO");
        usuario.setEstado(true);
        usuario.setBodega(bodega);

        when(usuarioRepository.findByUsernameIgnoreCase("cajero1")).thenReturn(Optional.of(usuario));

        UserDetails details = userDetailsService.loadUserByUsername("cajero1");

        assertNotNull(details);
        assertEquals("cajero1", details.getUsername());
        assertTrue(details.isEnabled());
        assertTrue(details.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_CAJERO")));
    }

    @Test
    void testLoadUserByUsername_UsuarioDesactivado_LanzaDisabledException() {
        Usuario usuario = new Usuario();
        usuario.setUsername("bloqueado");
        usuario.setPassword("hashedPass");
        usuario.setRol("CAJERO");
        usuario.setEstado(false);

        when(usuarioRepository.findByUsernameIgnoreCase("bloqueado")).thenReturn(Optional.of(usuario));

        DisabledException ex = assertThrows(DisabledException.class, () ->
                userDetailsService.loadUserByUsername("bloqueado")
        );

        assertTrue(ex.getMessage().contains("desactivada"));
    }

    @Test
    void testLoadUserByUsername_BodegaDesactivada_LanzaDisabledException() {
        Bodega bodega = new Bodega();
        bodega.setIdBodega(2L);
        bodega.setEstado(false); // Tienda suspendida o cancelada

        Usuario usuario = new Usuario();
        usuario.setUsername("admin_tienda2");
        usuario.setPassword("hashedPass");
        usuario.setRol("ADMIN");
        usuario.setEstado(true);
        usuario.setBodega(bodega);

        when(usuarioRepository.findByUsernameIgnoreCase("admin_tienda2")).thenReturn(Optional.of(usuario));

        DisabledException ex = assertThrows(DisabledException.class, () ->
                userDetailsService.loadUserByUsername("admin_tienda2")
        );

        assertTrue(ex.getMessage().contains("tienda o bodega asignada se encuentra desactivada"));
    }

    @Test
    void testLoadUserByUsername_SuperAdminBodegaDesactivada_PermiteLogin() {
        Bodega bodega = new Bodega();
        bodega.setIdBodega(3L);
        bodega.setEstado(false);

        Usuario superadmin = new Usuario();
        superadmin.setUsername("superadmin");
        superadmin.setPassword("hashedPass");
        superadmin.setRol("SUPERADMIN");
        superadmin.setEstado(true);
        superadmin.setBodega(bodega);

        when(usuarioRepository.findByUsernameIgnoreCase("superadmin")).thenReturn(Optional.of(superadmin));

        UserDetails details = userDetailsService.loadUserByUsername("superadmin");

        assertNotNull(details);
        assertEquals("superadmin", details.getUsername());
        assertTrue(details.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_SUPERADMIN")));
    }

    @Test
    void testLoadUserByUsername_UsuarioNoExiste_LanzaUsernameNotFoundException() {
        when(usuarioRepository.findByUsernameIgnoreCase("inexistente")).thenReturn(Optional.empty());

        assertThrows(UsernameNotFoundException.class, () ->
                userDetailsService.loadUserByUsername("inexistente")
        );
    }
}
