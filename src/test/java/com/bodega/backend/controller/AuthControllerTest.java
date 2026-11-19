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
    private com.bodega.backend.service.StarterPackService starterPackService;

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
        assertTrue(response.getBody().get("error").contains("Operación bloqueada temporalmente"));
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

    @Test
    void testRegistrarBodega_UsuarioAdminReservado_LanzaExcepcion() {
        com.bodega.backend.dto.RegistroBodegaDTO dto = new com.bodega.backend.dto.RegistroBodegaDTO();
        dto.setNombreComercial("Bodega El Éxito");
        dto.setUsername("admin");
        dto.setPassword("password123");

        when(request.getRemoteAddr()).thenReturn("127.0.0.1");

        RuntimeException ex = assertThrows(RuntimeException.class, () ->
                authController.registrarBodega(dto, request)
        );

        assertTrue(ex.getMessage().contains("está reservado"));
    }

    @Test
    void testRegistrarBodega_Exitoso() {
        com.bodega.backend.dto.RegistroBodegaDTO dto = new com.bodega.backend.dto.RegistroBodegaDTO();
        dto.setNombreComercial("Minimarket Don Pepe");
        dto.setUsername("don_pepe");
        dto.setPassword("segura1234");
        dto.setPlan("BASICO");

        when(request.getRemoteAddr()).thenReturn("127.0.0.1");
        when(loginRateLimiterService.isBlocked(anyString(), eq("don_pepe"))).thenReturn(false);
        when(usuarioRepository.existsByUsernameIgnoreCase("don_pepe")).thenReturn(false);

        Bodega nuevaBodega = new Bodega();
        nuevaBodega.setIdBodega(10L);
        nuevaBodega.setNombreComercial("Minimarket Don Pepe");
        nuevaBodega.setPlan("PRO");

        when(bodegaRepository.save(any(Bodega.class))).thenReturn(nuevaBodega);
        when(passwordEncoder.encode("segura1234")).thenReturn("$2a$10$hashed");
        when(jwtUtil.generateToken("don_pepe", "ADMIN", 10L, "PRO")).thenReturn("jwt.token.nueva.bodega");

        ResponseEntity<Map<String, String>> response = authController.registrarBodega(dto, request);

        assertNotNull(response);
        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertEquals("jwt.token.nueva.bodega", response.getBody().get("token"));
        assertEquals("Minimarket Don Pepe", response.getBody().get("nombreBodega"));
        assertEquals("PRO", response.getBody().get("plan"));

        verify(starterPackService).provisionarStarterPackParaBodega(nuevaBodega);
        verify(usuarioRepository).save(any(Usuario.class));
    }

    @Test
    void testRegistrarBodega_ConGiroPolleria_GuardaGiroYRetornaEnRespuesta() {
        com.bodega.backend.dto.RegistroBodegaDTO dto = new com.bodega.backend.dto.RegistroBodegaDTO();
        dto.setNombreComercial("Pollería & Brasas El Carbón");
        dto.setUsername("carbon_admin");
        dto.setPassword("polleria123");
        dto.setGiroNegocio("POLLERIA");

        when(request.getRemoteAddr()).thenReturn("127.0.0.1");
        when(loginRateLimiterService.isBlocked(anyString(), eq("carbon_admin"))).thenReturn(false);
        when(usuarioRepository.existsByUsernameIgnoreCase("carbon_admin")).thenReturn(false);

        Bodega nuevaBodega = new Bodega();
        nuevaBodega.setIdBodega(20L);
        nuevaBodega.setNombreComercial("Pollería & Brasas El Carbón");
        nuevaBodega.setGiroNegocio("POLLERIA");
        nuevaBodega.setPlan("PRO");

        when(bodegaRepository.save(any(Bodega.class))).thenReturn(nuevaBodega);
        when(passwordEncoder.encode("polleria123")).thenReturn("$2a$10$hashed");
        when(jwtUtil.generateToken("carbon_admin", "ADMIN", 20L, "PRO")).thenReturn("jwt.token.polleria");

        ResponseEntity<Map<String, String>> response = authController.registrarBodega(dto, request);

        assertNotNull(response);
        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertEquals("POLLERIA", response.getBody().get("giroNegocio"));
        assertEquals("Pollería & Brasas El Carbón", response.getBody().get("nombreBodega"));
    }

    @Test
    void testLoginCajero_ConPinCorrecto_RetornaTokenYDatosTienda() {
        com.bodega.backend.dto.LoginCajeroPinDTO dto = new com.bodega.backend.dto.LoginCajeroPinDTO();
        dto.setIdBodega(1L);
        dto.setPin("1234");

        Usuario cajero = new Usuario();
        cajero.setIdUsuario(5L);
        cajero.setUsername("cajero_carlos");
        cajero.setNombreCompleto("Carlos Morales");
        cajero.setRol("CAJERO");
        cajero.setEstado(true);
        cajero.setPin("$2a$10$pinHashed");
        cajero.setBodega(bodega);

        when(request.getRemoteAddr()).thenReturn("127.0.0.1");
        when(loginRateLimiterService.isBlocked(anyString(), anyString())).thenReturn(false);
        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodega));
        when(usuarioRepository.findByBodega_IdBodegaAndEstadoTrue(1L)).thenReturn(java.util.List.of(cajero));
        when(passwordEncoder.matches("1234", "$2a$10$pinHashed")).thenReturn(true);
        when(jwtUtil.generateToken("cajero_carlos", "CAJERO", 1L, "PRO")).thenReturn("jwt.token.cajero.carlos");

        ResponseEntity<Map<String, String>> response = authController.loginCajero(dto, request);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("jwt.token.cajero.carlos", response.getBody().get("token"));
        assertEquals("CAJERO", response.getBody().get("rol"));
        assertEquals("Carlos Morales", response.getBody().get("nombreCompleto"));
        assertEquals("Bodega Central", response.getBody().get("nombreBodega"));
    }

    @Test
    void testLoginCajero_ConPinIncorrecto_RetornaUnauthorized() {
        com.bodega.backend.dto.LoginCajeroPinDTO dto = new com.bodega.backend.dto.LoginCajeroPinDTO();
        dto.setIdBodega(1L);
        dto.setPin("9999");

        Usuario cajero = new Usuario();
        cajero.setIdUsuario(5L);
        cajero.setUsername("cajero_carlos");
        cajero.setPin("$2a$10$pinHashed");
        cajero.setEstado(true);
        cajero.setBodega(bodega);

        when(request.getRemoteAddr()).thenReturn("127.0.0.1");
        when(loginRateLimiterService.isBlocked(anyString(), anyString())).thenReturn(false);
        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodega));
        when(usuarioRepository.findByBodega_IdBodegaAndEstadoTrue(1L)).thenReturn(java.util.List.of(cajero));
        when(passwordEncoder.matches("9999", "$2a$10$pinHashed")).thenReturn(false);

        ResponseEntity<Map<String, String>> response = authController.loginCajero(dto, request);

        assertNotNull(response);
        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
        assertTrue(response.getBody().get("error").contains("PIN incorrecto"));
    }

    @Test
    void testListarCajerosTerminal_RetornaAvataresEIniciales() {
        Usuario c1 = new Usuario();
        c1.setIdUsuario(10L);
        c1.setNombreCompleto("Carlos Morales");
        c1.setUsername("carlos");
        c1.setRol("CAJERO");

        Usuario c2 = new Usuario();
        c2.setIdUsuario(11L);
        c2.setNombreCompleto("Lucía Romero");
        c2.setUsername("lucia");
        c2.setRol("CAJERO");

        when(usuarioRepository.findByBodega_IdBodegaAndEstadoTrue(1L)).thenReturn(java.util.List.of(c1, c2));

        ResponseEntity<java.util.List<com.bodega.backend.dto.CajeroTerminalDTO>> response = authController.listarCajerosTerminal(1L);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(2, response.getBody().size());
        assertEquals("CM", response.getBody().get(0).getIniciales());
        assertEquals("Carlos Morales", response.getBody().get(0).getNombreCompleto());
        assertEquals("LR", response.getBody().get(1).getIniciales());
    }
}
