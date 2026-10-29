package com.bodega.backend.service;

import com.bodega.backend.dto.WebhookYapeDTO;
import com.bodega.backend.entity.YapeTransaccionRecibida;
import com.bodega.backend.repository.YapeTransaccionRecibidaRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class YapeWebhookServiceTest {

    @Mock
    private YapeTransaccionRecibidaRepository yapeTransaccionRecibidaRepository;

    @InjectMocks
    private YapeWebhookService yapeWebhookService;

    private static final String VALID_SECRET = "CajayaYapeSecretKey2026Secure";

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(yapeWebhookService, "configuredSecret", VALID_SECRET);
    }

    @Test
    void testProcesarNotificacionYape_SecretInvalido_LanzaAccessDeniedException() {
        WebhookYapeDTO dto = new WebhookYapeDTO();
        dto.setCodigoOperacion("849201");
        dto.setMonto(new BigDecimal("100.00"));

        assertThrows(AccessDeniedException.class, () ->
                yapeWebhookService.procesarNotificacionYape("CLAVE_INCORRECTA", dto));

        verify(yapeTransaccionRecibidaRepository, never()).save(any());
    }

    @Test
    void testProcesarNotificacionYape_DatosEstructurados_GuardaTransaccionExitosamente() {
        WebhookYapeDTO dto = new WebhookYapeDTO();
        dto.setCodigoOperacion("849201");
        dto.setMonto(new BigDecimal("100.00"));
        dto.setBilletera("YAPE");
        dto.setNombreRemitente("Pedro Quispe");

        when(yapeTransaccionRecibidaRepository.findFirstByCodigoOperacion("849201")).thenReturn(Optional.empty());
        when(yapeTransaccionRecibidaRepository.save(any(YapeTransaccionRecibida.class))).thenAnswer(inv -> inv.getArgument(0));

        YapeTransaccionRecibida resultado = yapeWebhookService.procesarNotificacionYape(VALID_SECRET, dto);

        assertNotNull(resultado);
        assertEquals("849201", resultado.getCodigoOperacion());
        assertEquals(new BigDecimal("100.00"), resultado.getMonto());
        assertEquals("YAPE", resultado.getBilletera());
        assertEquals("Pedro Quispe", resultado.getNombreRemitente());
        assertFalse(resultado.isUsado());
        verify(yapeTransaccionRecibidaRepository, times(1)).save(any(YapeTransaccionRecibida.class));
    }

    @Test
    void testProcesarNotificacionYape_TextoCrudoRegexParsing_ExtraeMontoYCodigoCorrectamente() {
        WebhookYapeDTO dto = new WebhookYapeDTO();
        dto.setTextoNotificacion("¡Yape! Te llegó un pago de S/ 50.00 de Juan Perez. Nro operacion: 994821");

        when(yapeTransaccionRecibidaRepository.findFirstByCodigoOperacion("994821")).thenReturn(Optional.empty());
        when(yapeTransaccionRecibidaRepository.save(any(YapeTransaccionRecibida.class))).thenAnswer(inv -> inv.getArgument(0));

        YapeTransaccionRecibida resultado = yapeWebhookService.procesarNotificacionYape(VALID_SECRET, dto);

        assertNotNull(resultado);
        assertEquals("994821", resultado.getCodigoOperacion());
        assertEquals(new BigDecimal("50.00"), resultado.getMonto());
        assertEquals("YAPE", resultado.getBilletera());
        assertEquals("Juan Perez", resultado.getNombreRemitente());
        assertFalse(resultado.isUsado());
    }

    @Test
    void testProcesarNotificacionYape_NotificacionDuplicada_RetornaExistenteIdempotente() {
        WebhookYapeDTO dto = new WebhookYapeDTO();
        dto.setCodigoOperacion("849201");
        dto.setMonto(new BigDecimal("100.00"));

        YapeTransaccionRecibida existente = new YapeTransaccionRecibida();
        existente.setCodigoOperacion("849201");
        existente.setMonto(new BigDecimal("100.00"));

        when(yapeTransaccionRecibidaRepository.findFirstByCodigoOperacion("849201")).thenReturn(Optional.of(existente));

        YapeTransaccionRecibida resultado = yapeWebhookService.procesarNotificacionYape(VALID_SECRET, dto);

        assertSame(existente, resultado);
        verify(yapeTransaccionRecibidaRepository, never()).save(any());
    }
}
