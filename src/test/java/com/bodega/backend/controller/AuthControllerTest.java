package com.bodega.backend.controller;

import com.bodega.backend.dto.AuthDTO;
import com.bodega.backend.dto.CambiarPasswordDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.UsuarioRepository;
import com.bodega.backend.security.JwtUtil;
import com.bodega.backend.security.LoginRateLimiterService;
import com.bodega.backend.security.UserSecurityCacheService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.security.Principal;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class AuthControllerTest {

    @Mock
    private AuthenticationManager authenticationManager;

    @Mock
    private JwtUtil jwtUtil;

    @Mock
    private UsuarioRepository usuarioRepository;

    @Mock
    private BodegaRepository bodegaRepository;

    @Mock
    private CategoriaRepository categoriaRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private LoginRateLimiterService loginRateLimiterService;

    @Mock
    private UserSecurityCacheService userSecurityCacheService;

    @Mock
    private HttpServletRequest request;

    @Mock
    private Principal principal;

    @InjectMocks
    private AuthController authController;

    private Usuario usuario;
    private Bodega bodega;

    @BeforeEach
    void setUp() {
        bodega = new Bodega();
        bodega.setIdBodega(1L);
        bodega.setNombreComercial("Bodega Central");
        bodega.setPlan("PRO");
        bodega.setEstado(true);

        usuario = new Usuario();
        usuario.setIdUsuario(1L);
        usuario.setUsername("admin");
        usuario.setPassword("$2a$10$encodedpassword");
        usuario.setRol("ADMIN");
        usuario.setEstado(true);
        usuario.setBodega(bodega);
    }

    @Test
    void testLogin_CuandoEstaBloqueadoPorRateLimiter_Retorna429() {
        AuthDTO dto = new AuthDTO();
        dto.setUsername("admin");
        dto.setPassword("1234");

        when(request.getRemoteAddr()).thenReturn("192.168.1.1");
        when(loginRateLimiterService.isBlocked(anyString(), eq("admin"))).thenReturn(true);
        when(loginRateLimiterService.getRemainingBlockMinutes(anyString(), eq("admin"))).thenReturn(4L);

        ResponseEntity<Map<String, String>> response = authController.login(dto, request);

        assertNotNull(response);
        assertEquals(HttpStatus.TOO_MANY_REQUESTS, response.getStatusCode());
        assertTrue(response.getBody().get("error").contains("bloqueado temporalmente"));
    }

    @Test
    void testLogin_Exitoso() {
        AuthDTO dto = new AuthDTO();
        dto.setUsername("admin");
        dto.setPassword("correctPassword");

        when(request.getRemoteAddr()).thenReturn("192.168.1.1");
        when(loginRateLimiterService.isBlocked(anyString(), eq("admin"))).thenReturn(false);
        when(authenticationManager.authenticate(any(UsernamePasswordAuthenticationToken.class)))
                .thenReturn(new UsernamePasswordAuthenticationToken("admin", "correctPassword"));
        when(usuarioRepository.findByUsernameIgnoreCase("admin")).thenReturn(Optional.of(usuario));
        when(jwtUtil.generateToken("admin", "ADMIN", 1L, "PRO")).thenReturn("jwt.token.mock");

        ResponseEntity<Map<String, String>> response = authController.login(dto, request);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("jwt.token.mock", response.getBody().get("token"));
        assertEquals("ADMIN", response.getBody().get("rol"));
        assertEquals("Bodega Central", response.getBody().get("nombreBodega"));
        verify(loginRateLimiterService).resetAttempts(anyString(), eq("admin"));
    }

    @Test
    void testCambiarPassword_SinPrincipal_Retorna401() {
        CambiarPasswordDTO dto = new CambiarPasswordDTO();
        dto.setPasswordActual("claveVieja123");
        dto.setNuevaPassword("claveNueva456");

        ResponseEntity<Map<String, String>> response = authController.cambiarPassword(dto, null, request);

        assertNotNull(response);
        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

    @Test
    void testCambiarPassword_MismaPassword_LanzaExcepcion() {
        CambiarPasswordDTO dto = new CambiarPasswordDTO();
        dto.setPasswordActual("clave12345");
        dto.setNuevaPassword("clave12345");

        when(principal.getName()).thenReturn("admin");
        when(request.getRemoteAddr()).thenReturn("127.0.0.1");

        RuntimeException ex = assertThrows(RuntimeException.class, () ->
                authController.cambiarPassword(dto, principal, request)
        );

        assertTrue(ex.getMessage().contains("no puede ser idéntica"));
    }

    @Test
    void testCambiarPassword_Exitoso() {
        CambiarPasswordDTO dto = new CambiarPasswordDTO();
        dto.setPasswordActual("claveVieja123");
        dto.setNuevaPassword("claveNueva456");

        when(principal.getName()).thenReturn("admin");
        when(request.getRemoteAddr()).thenReturn("127.0.0.1");
        when(usuarioRepository.findByUsernameIgnoreCase("admin")).thenReturn(Optional.of(usuario));
        when(passwordEncoder.matches("claveVieja123", usuario.getPassword())).thenReturn(true);
        when(passwordEncoder.encode("claveNueva456")).thenReturn("$2a$10$newhash");

        ResponseEntity<Map<String, String>> response = authController.cambiarPassword(dto, principal, request);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertTrue(response.getBody().get("mensaje").contains("exitosamente"));
        verify(usuarioRepository).save(usuario);
        verify(userSecurityCacheService).evict("admin");
    }
}
