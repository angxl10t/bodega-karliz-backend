package com.bodega.backend.controller;

import com.bodega.backend.dto.WebhookYapeDTO;
import com.bodega.backend.entity.YapeTransaccionRecibida;
import com.bodega.backend.service.YapeWebhookService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class PagoWebhookControllerTest {

    @Mock
    private YapeWebhookService yapeWebhookService;

    @InjectMocks
    private PagoWebhookController pagoWebhookController;

    private YapeTransaccionRecibida tx;

    @BeforeEach
    void setUp() {
        tx = new YapeTransaccionRecibida();
        tx.setIdTransaccion(1L);
        tx.setCodigoOperacion("849201");
        tx.setMonto(new BigDecimal("100.00"));
        tx.setBilletera("YAPE");
        tx.setUsado(false);
    }

    @Test
    void testRecibirNotificacionYapePost_ConHeaderValido_RetornaOk() {
        WebhookYapeDTO dto = new WebhookYapeDTO();
        dto.setCodigoOperacion("849201");
        dto.setMonto(new BigDecimal("100.00"));

        when(yapeWebhookService.procesarNotificacionYape(eq("CajayaYapeSecretKey2026Secure"), any(WebhookYapeDTO.class)))
                .thenReturn(tx);

        ResponseEntity<Map<String, Object>> res = pagoWebhookController.recibirNotificacionYapePost(
                "CajayaYapeSecretKey2026Secure", null, dto);

        assertNotNull(res);
        assertEquals(HttpStatus.OK, res.getStatusCode());
        assertEquals("PROCESSED", res.getBody().get("status"));
        assertEquals("849201", res.getBody().get("codigoOperacion"));
    }

    @Test
    void testRecibirNotificacionYapeGet_ConQueryParamSecret_RetornaOk() {
        when(yapeWebhookService.procesarNotificacionYape(eq("CajayaYapeSecretKey2026Secure"), any(WebhookYapeDTO.class)))
                .thenReturn(tx);

        ResponseEntity<Map<String, Object>> res = pagoWebhookController.recibirNotificacionYapeGet(
                null,
                "CajayaYapeSecretKey2026Secure",
                "¡Yape! Te llegó un pago de S/ 100.00 de Pedro Quispe. Nro operacion: 849201",
                null,
                null,
                null,
                null,
                null
        );

        assertNotNull(res);
        assertEquals(HttpStatus.OK, res.getStatusCode());
        assertEquals("PROCESSED", res.getBody().get("status"));
        assertEquals("849201", res.getBody().get("codigoOperacion"));
        assertEquals(new BigDecimal("100.00"), res.getBody().get("monto"));
    }

    @Test
    void testListarTransaccionesYape_SuperAdmin_RetornaLista() {
        when(yapeWebhookService.listarTodas()).thenReturn(List.of(tx));

        ResponseEntity<List<YapeTransaccionRecibida>> res = pagoWebhookController.listarTransaccionesYape();

        assertNotNull(res);
        assertEquals(HttpStatus.OK, res.getStatusCode());
        assertEquals(1, res.getBody().size());
        assertEquals("849201", res.getBody().get(0).getCodigoOperacion());
    }
}
