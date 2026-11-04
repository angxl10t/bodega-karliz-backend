package com.bodega.backend.service;

import com.bodega.backend.entity.RecuperacionClave;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.RecuperacionClaveRepository;
import com.bodega.backend.repository.UsuarioRepository;
import com.bodega.backend.security.LoginRateLimiterService;
import com.bodega.backend.security.UserSecurityCacheService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.OffsetDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class RecuperacionClaveServiceTest {

    @Mock
    private UsuarioRepository usuarioRepository;

    @Mock
    private RecuperacionClaveRepository recuperacionClaveRepository;

    @Mock
    private EmailService emailService;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private LoginRateLimiterService loginRateLimiterService;

    @Mock
    private UserSecurityCacheService userSecurityCacheService;

    @InjectMocks
    private RecuperacionClaveService recuperacionClaveService;

    private Usuario testUser;

    @BeforeEach
    void setUp() {
        testUser = new Usuario();
        testUser.setIdUsuario(10L);
        testUser.setUsername("bodega-karliz");
        testUser.setEmail("karliz@bodega.pe");
        testUser.setPassword("hashedOldPassword");
        testUser.setRol("ADMIN");
        testUser.setEstado(true);
    }

    @Test
    void solicitarCodigo_conUsuarioValido_generaOtpGuardaRegistroYEnviaCorreo() {
        when(loginRateLimiterService.isBlocked(anyString(), anyString())).thenReturn(false);
        when(usuarioRepository.findByUsernameOrEmailIgnoreCase("bodega-karliz")).thenReturn(Optional.of(testUser));
        when(recuperacionClaveRepository.countByUsuarioAndFechaCreacionAfter(eq(testUser), any())).thenReturn(0L);
        when(recuperacionClaveRepository.findByUsuarioAndUsadoFalse(testUser)).thenReturn(Collections.emptyList());
        when(emailService.enviarCodigoRecuperacion(anyString(), anyString(), anyString())).thenReturn(true);

        Map<String, String> res = recuperacionClaveService.solicitarCodigo("bodega-karliz", "192.168.1.1");

        assertNotNull(res);
        assertTrue(res.get("mensaje").contains("código de verificación"));
        assertEquals("k***z@bodega.pe", res.get("emailEnmascarado"));
        assertEquals("15", res.get("expiraMinutos"));

        verify(recuperacionClaveRepository).save(any(RecuperacionClave.class));
        verify(emailService).enviarCodigoRecuperacion(eq("karliz@bodega.pe"), eq("bodega-karliz"), anyString());
    }

    @Test
    void solicitarCodigo_conUsuarioInexistente_noFugaExistenciaYRetornaMensajeGenerico() {
        when(loginRateLimiterService.isBlocked(anyString(), anyString())).thenReturn(false);
        when(usuarioRepository.findByUsernameOrEmailIgnoreCase("fantasma")).thenReturn(Optional.empty());

        Map<String, String> res = recuperacionClaveService.solicitarCodigo("fantasma", "192.168.1.1");

        assertNotNull(res);
        assertTrue(res.get("mensaje").contains("código de verificación"));
        assertEquals("", res.get("emailEnmascarado"));
        verify(loginRateLimiterService).registerFailedAttempt("192.168.1.1", "fantasma");
        verify(emailService, never()).enviarCodigoRecuperacion(anyString(), anyString(), anyString());
    }

    @Test
    void verificarCodigo_conCodigoCorrecto_retornaValido() {
        when(loginRateLimiterService.isBlocked(anyString(), anyString())).thenReturn(false);
        when(usuarioRepository.findByUsernameOrEmailIgnoreCase("bodega-karliz")).thenReturn(Optional.of(testUser));

        String codigoValido = "123456";
        String hashValido = calcularSha256(codigoValido);

        RecuperacionClave token = new RecuperacionClave();
        token.setUsuario(testUser);
        token.setCodigoHash(hashValido);
        token.setExpiracion(OffsetDateTime.now().plusMinutes(10));
        token.setUsado(false);
        token.setIntentosFallidos(0);

        when(recuperacionClaveRepository.findByUsuarioAndUsadoFalseAndExpiracionAfterOrderByFechaCreacionDesc(
                eq(testUser), any())).thenReturn(List.of(token));

        Map<String, String> res = recuperacionClaveService.verificarCodigo("bodega-karliz", codigoValido, "192.168.1.1");

        assertEquals("true", res.get("valido"));
    }

    @Test
    void verificarCodigo_conCodigoIncorrecto_incrementaIntentosYLanzaExcepcion() {
        when(loginRateLimiterService.isBlocked(anyString(), anyString())).thenReturn(false);
        when(usuarioRepository.findByUsernameOrEmailIgnoreCase("bodega-karliz")).thenReturn(Optional.of(testUser));

        RecuperacionClave token = new RecuperacionClave();
        token.setUsuario(testUser);
        token.setCodigoHash(calcularSha256("123456"));
        token.setExpiracion(OffsetDateTime.now().plusMinutes(10));
        token.setUsado(false);
        token.setIntentosFallidos(1);

        when(recuperacionClaveRepository.findByUsuarioAndUsadoFalseAndExpiracionAfterOrderByFechaCreacionDesc(
                eq(testUser), any())).thenReturn(List.of(token));

        RuntimeException ex = assertThrows(RuntimeException.class, () ->
                recuperacionClaveService.verificarCodigo("bodega-karliz", "999999", "192.168.1.1"));

        assertTrue(ex.getMessage().contains("Código incorrecto"));
        assertEquals(2, token.getIntentosFallidos());
        verify(recuperacionClaveRepository).save(token);
    }

    @Test
    void restablecerPassword_conCodigoValido_actualizaContrasenaEInvalidaToken() {
        when(usuarioRepository.findByUsernameOrEmailIgnoreCase("bodega-karliz")).thenReturn(Optional.of(testUser));
        when(passwordEncoder.encode("nuevaClave2026")).thenReturn("hashedNuevaClave2026");

        String codigoValido = "555666";
        RecuperacionClave token = new RecuperacionClave();
        token.setUsuario(testUser);
        token.setCodigoHash(calcularSha256(codigoValido));
        token.setExpiracion(OffsetDateTime.now().plusMinutes(10));
        token.setUsado(false);

        when(recuperacionClaveRepository.findByUsuarioAndUsadoFalseAndExpiracionAfterOrderByFechaCreacionDesc(
                eq(testUser), any())).thenReturn(List.of(token));

        Map<String, String> res = recuperacionClaveService.restablecerPassword(
                "bodega-karliz", codigoValido, "nuevaClave2026", "192.168.1.1");

        assertTrue(res.get("mensaje").contains("éxito"));
        assertEquals("hashedNuevaClave2026", testUser.getPassword());
        assertNotNull(testUser.getFechaCambioClave());
        assertTrue(token.getUsado());

        verify(usuarioRepository).save(testUser);
        verify(recuperacionClaveRepository).save(token);
        verify(loginRateLimiterService).resetAttempts("192.168.1.1", "bodega-karliz");
        verify(userSecurityCacheService).evict("bodega-karliz");
    }

    @Test
    void enmascararEmail_formateaCorrectamente() {
        assertEquals("k***z@bodega.pe", EmailService.enmascararEmail("karliz@bodega.pe"));
        assertEquals("r***o@gmail.com", EmailService.enmascararEmail("rodrigo@gmail.com"));
        assertEquals("j***@gmail.com", EmailService.enmascararEmail("jo@gmail.com"));
        assertEquals("***@***", EmailService.enmascararEmail("invalido"));
    }

    private String calcularSha256(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] encodedhash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder(2 * encodedhash.length);
            for (byte b : encodedhash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) {
                    hexString.append('0');
                }
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
