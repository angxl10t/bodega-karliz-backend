package com.bodega.backend.service;

import com.bodega.backend.dto.BodegaDTO;
import com.bodega.backend.dto.PagoYapeDTO;
import com.bodega.backend.dto.WebhookYapeDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.PagoSuscripcion;
import com.bodega.backend.entity.YapeTransaccionRecibida;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.PagoSuscripcionRepository;
import com.bodega.backend.repository.YapeTransaccionRecibidaRepository;
import com.bodega.backend.security.UserSecurityCacheService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class PagoYapeE2EValidationTest {

    @Mock
    private YapeTransaccionRecibidaRepository yapeTransaccionRecibidaRepository;

    @Mock
    private BodegaRepository bodegaRepository;

    @Mock
    private TenantService tenantService;

    @Mock
    private UserSecurityCacheService userSecurityCacheService;

    @Mock
    private PagoSuscripcionRepository pagoSuscripcionRepository;

    @InjectMocks
    private YapeWebhookService yapeWebhookService;

    @InjectMocks
    private BodegaService bodegaService;

    private static final String SECRET_OFICIAL = "CajayaYapeSecretKey2026Secure";
    private Bodega bodega;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(yapeWebhookService, "configuredSecret", SECRET_OFICIAL);

        bodega = new Bodega();
        bodega.setIdBodega(10L);
        bodega.setNombreComercial("Minimarket Don Pepe");
        bodega.setPlan("BASICO");
        bodega.setEstado(true);
        bodega.setFechaVencimientoPlan(OffsetDateTime.now().plusDays(2));

        lenient().when(tenantService.getCurrentBodega()).thenReturn(bodega);
        lenient().when(bodegaRepository.save(any(Bodega.class))).thenAnswer(i -> i.getArgument(0));
    }

    @Test
    @DisplayName("Escenario 1: Rechazo inmediato de código inventado sin abono real")
    void escenario1_RechazoDeCodigoFalso() {
        PagoYapeDTO solicitud = new PagoYapeDTO();
        solicitud.setCodigoOperacion("99988877");
        solicitud.setPlan("PRO");
        solicitud.setMonto(new BigDecimal("100.00"));
        solicitud.setBilletera("YAPE");

        // Simular que en la base de datos de abonos bancarios no existe ese código
        when(yapeTransaccionRecibidaRepository.findFirstByCodigoOperacionAndUsadoFalse("99988877"))
                .thenReturn(Optional.empty());
        when(yapeTransaccionRecibidaRepository.findFirstByCodigoOperacion("99988877"))
                .thenReturn(Optional.empty());

        RuntimeException ex = assertThrows(RuntimeException.class, () ->
                bodegaService.registrarPagoYape(solicitud));

        assertTrue(ex.getMessage().contains("No se encontró ningún abono de YAPE por S/ 100.00"));
        verify(bodegaRepository, never()).save(any());
        verify(pagoSuscripcionRepository, never()).save(any());
    }

    @Test
    @DisplayName("Escenario 2: MacroDroid envía notificación push y el sistema la parsea y almacena en BD")
    void escenario2_MacroDroidEnviaNotificacionYape() {
        WebhookYapeDTO push = new WebhookYapeDTO();
        // Texto real generado por Yape en las notificaciones de Android
        push.setTextoNotificacion("¡Yape! Te llegó un pago de S/ 100.00 de Pedro Quispe. Nro operacion: 849201");

        when(yapeTransaccionRecibidaRepository.findFirstByCodigoOperacion("849201")).thenReturn(Optional.empty());
        when(yapeTransaccionRecibidaRepository.save(any(YapeTransaccionRecibida.class))).thenAnswer(i -> i.getArgument(0));

        YapeTransaccionRecibida tx = yapeWebhookService.procesarNotificacionYape(SECRET_OFICIAL, push);

        assertNotNull(tx);
        assertEquals("849201", tx.getCodigoOperacion());
        assertEquals(new BigDecimal("100.00"), tx.getMonto());
        assertEquals("YAPE", tx.getBilletera());
        assertEquals("Pedro Quispe", tx.getNombreRemitente());
        assertFalse(tx.isUsado());
    }

    @Test
    @DisplayName("Escenario 3: Bodeguero confirma el pago real -> Sistema concilia, marca usado y suma 30 días")
    void escenario3_BodegueroConfirmaPagoReal_ActivaSuscripcion() {
        // 1. Simular la transacción que llegó por el webhook en BD
        YapeTransaccionRecibida tx = new YapeTransaccionRecibida();
        tx.setIdTransaccion(1L);
        tx.setCodigoOperacion("849201");
        tx.setMonto(new BigDecimal("100.00"));
        tx.setBilletera("YAPE");
        tx.setNombreRemitente("Pedro Quispe");
        tx.setUsado(false);

        when(yapeTransaccionRecibidaRepository.findFirstByCodigoOperacionAndUsadoFalse("849201"))
                .thenReturn(Optional.of(tx));

        // 2. El bodeguero envía su solicitud de Plan PRO por S/ 100
        PagoYapeDTO solicitud = new PagoYapeDTO();
        solicitud.setCodigoOperacion("849201");
        solicitud.setPlan("PRO");
        solicitud.setMonto(new BigDecimal("100.00"));
        solicitud.setBilletera("YAPE");

        OffsetDateTime vencimientoAnterior = bodega.getFechaVencimientoPlan();
        BodegaDTO res = bodegaService.registrarPagoYape(solicitud);

        assertNotNull(res);
        assertEquals("PRO", res.getPlan());
        assertTrue(res.getFechaVencimientoPlan().isAfter(vencimientoAnterior.plusDays(29)));

        // Verificar que la transacción bancaria quedó marcada como usada para que nadie más la use
        assertTrue(tx.isUsado());
        assertEquals(10L, tx.getIdBodegaAsignada());
        assertNotNull(tx.getFechaUso());
        verify(yapeTransaccionRecibidaRepository, times(1)).save(tx);
        verify(pagoSuscripcionRepository, times(1)).save(any(PagoSuscripcion.class));
    }

    @Test
    @DisplayName("Escenario 4: Intento de reutilización del mismo voucher por otro usuario -> Rechazo estricto")
    void escenario4_ReutilizacionDeComprobante_Bloqueado() {
        // La transacción ya está marcada como usada en la base de datos
        YapeTransaccionRecibida txUsada = new YapeTransaccionRecibida();
        txUsada.setCodigoOperacion("849201");
        txUsada.setMonto(new BigDecimal("100.00"));
        txUsada.setUsado(true);

        when(yapeTransaccionRecibidaRepository.findFirstByCodigoOperacionAndUsadoFalse("849201"))
                .thenReturn(Optional.empty());
        when(yapeTransaccionRecibidaRepository.findFirstByCodigoOperacion("849201"))
                .thenReturn(Optional.of(txUsada));

        PagoYapeDTO solicitud = new PagoYapeDTO();
        solicitud.setCodigoOperacion("849201");
        solicitud.setPlan("PRO");
        solicitud.setMonto(new BigDecimal("100.00"));
        solicitud.setBilletera("YAPE");

        RuntimeException ex = assertThrows(RuntimeException.class, () ->
                bodegaService.registrarPagoYape(solicitud));

        assertTrue(ex.getMessage().contains("ya fue validado y canjeado previamente"));
        verify(bodegaRepository, never()).save(any());
    }

    @Test
    @DisplayName("Escenario 5: Abono real es de S/ 50 pero bodeguero intenta activar Plan PRO de S/ 100 -> Rechazo")
    void escenario5_MontoInsuficienteEnAbonoReal_Rechazado() {
        // Llegó un Yape real de S/ 50
        YapeTransaccionRecibida tx = new YapeTransaccionRecibida();
        tx.setCodigoOperacion("554433");
        tx.setMonto(new BigDecimal("50.00"));
        tx.setUsado(false);

        when(yapeTransaccionRecibidaRepository.findFirstByCodigoOperacionAndUsadoFalse("554433"))
                .thenReturn(Optional.of(tx));

        PagoYapeDTO solicitud = new PagoYapeDTO();
        solicitud.setCodigoOperacion("554433");
        solicitud.setPlan("PRO");
        solicitud.setMonto(new BigDecimal("100.00"));
        solicitud.setBilletera("YAPE");

        RuntimeException ex = assertThrows(RuntimeException.class, () ->
                bodegaService.registrarPagoYape(solicitud));

        assertTrue(ex.getMessage().contains("monto insuficiente para el Plan PRO"));
        assertFalse(tx.isUsado());
        verify(bodegaRepository, never()).save(any());
    }

    @Test
    @DisplayName("Escenario 6: Llamada al webhook con clave secreta incorrecta -> 403 Access Denied")
    void escenario6_WebhookConSecretInvalido_Bloqueado() {
        WebhookYapeDTO push = new WebhookYapeDTO();
        push.setCodigoOperacion("123456");
        push.setMonto(new BigDecimal("100.00"));

        assertThrows(AccessDeniedException.class, () ->
                yapeWebhookService.procesarNotificacionYape("CLAVE_FALSA_HACKER", push));

        verify(yapeTransaccionRecibidaRepository, never()).save(any());
    }
}
