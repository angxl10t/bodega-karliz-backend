package com.bodega.backend.service;

import com.bodega.backend.dto.NotificacionDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Notificacion;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.NotificacionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class NotificacionServiceTest {

    @Mock
    private NotificacionRepository notificacionRepository;

    @InjectMocks
    private NotificacionService notificacionService;

    private Bodega bodega;
    private Usuario usuarioCajero;
    private Usuario usuarioAdmin;

    @BeforeEach
    void setUp() {
        bodega = new Bodega();
        bodega.setIdBodega(1L);
        bodega.setNombreComercial("Bodega Karliz");

        usuarioCajero = new Usuario();
        usuarioCajero.setIdUsuario(10L);
        usuarioCajero.setUsername("cajero1");
        usuarioCajero.setRol("CAJERO");
        usuarioCajero.setBodega(bodega);

        usuarioAdmin = new Usuario();
        usuarioAdmin.setIdUsuario(20L);
        usuarioAdmin.setUsername("admin1");
        usuarioAdmin.setRol("ADMIN");
        usuarioAdmin.setBodega(bodega);
    }

    @Test
    @DisplayName("Cajero no puede marcar como leída una notificación exclusiva de ADMIN (Protección IDOR de Rol)")
    void testCajeroNoPuedeMarcarAlertaAdmin() {
        Notificacion notifAdmin = Notificacion.builder()
                .idNotificacion(500L)
                .bodega(bodega)
                .rolDestinatario("ADMIN")
                .tipo("STOCK_CRITICO")
                .titulo("⚠️ Stock Crítico")
                .mensaje("Quedan 2 unidades")
                .leido(false)
                .build();

        when(notificacionRepository.findById(500L)).thenReturn(Optional.of(notifAdmin));

        // Intento de marcado por cajero (idUsuario=10, rol=CAJERO)
        boolean resultado = notificacionService.marcarComoLeida(1L, 10L, "CAJERO", 500L);

        assertFalse(resultado, "Un cajero no debe poder marcar una notificación de rol ADMIN");
        verify(notificacionRepository, never()).save(any(Notificacion.class));
    }

    @Test
    @DisplayName("Admin puede marcar como leída cualquier notificación de su bodega")
    void testAdminPuedeMarcarAlerta() {
        Notificacion notif = Notificacion.builder()
                .idNotificacion(501L)
                .bodega(bodega)
                .rolDestinatario("ADMIN")
                .tipo("STOCK_CRITICO")
                .titulo("⚠️ Stock Crítico")
                .mensaje("Quedan 2 unidades")
                .leido(false)
                .build();

        when(notificacionRepository.findById(501L)).thenReturn(Optional.of(notif));

        boolean resultado = notificacionService.marcarComoLeida(1L, 20L, "ADMIN", 501L);

        assertTrue(resultado);
        assertTrue(notif.getLeido());
        assertNotNull(notif.getFechaLeido());
        verify(notificacionRepository).save(notif);
    }

    @Test
    @DisplayName("No permite marcar notificaciones de otra bodega (Aislamiento Multi-Tenant)")
    void testAislamientoMultiTenantEnMarcarLeida() {
        Bodega otraBodega = new Bodega();
        otraBodega.setIdBodega(999L);

        Notificacion notifOtra = Notificacion.builder()
                .idNotificacion(502L)
                .bodega(otraBodega)
                .rolDestinatario("TODOS")
                .tipo("NUEVO_PEDIDO_WEB")
                .titulo("Pedido")
                .mensaje("Msg")
                .leido(false)
                .build();

        when(notificacionRepository.findById(502L)).thenReturn(Optional.of(notifOtra));

        // Usuario de bodega 1 intenta marcar notificación de bodega 999
        boolean resultado = notificacionService.marcarComoLeida(1L, 10L, "CAJERO", 502L);

        assertFalse(resultado, "No se puede alterar notificaciones de otro tenant");
        verify(notificacionRepository, never()).save(any(Notificacion.class));
    }

    @Test
    @DisplayName("Deduplicación de stock crítico consulta correctamente el repositorio")
    void testDeduplicacionStockCritico() {
        when(notificacionRepository.existeAlertaStockPendiente(eq(1L), contains("12"), isNull()))
                .thenReturn(true);

        boolean yaExiste = notificacionService.existeAlertaStockPendiente(1L, 12L, false);

        assertTrue(yaExiste, "Debe detectar que ya existe una alerta activa para evitar saturar la BD");
    }

    @Test
    @DisplayName("Suscripción SSE rechaza llamadas sin idBodega")
    void testSuscripcionRequiereIdBodega() {
        assertThrows(IllegalArgumentException.class, () -> {
            notificacionService.suscribir(null, 10L, "CAJERO");
        });
    }

    @Test
    @DisplayName("Suscripción SSE emite evento INIT con conteo inicial de no leídas")
    void testSuscripcionExitosa() {
        when(notificacionRepository.contarNoLeidas(1L, 10L, "CAJERO")).thenReturn(4L);

        SseEmitter emitter = notificacionService.suscribir(1L, 10L, "CAJERO");

        assertNotNull(emitter);
        verify(notificacionRepository).contarNoLeidas(1L, 10L, "CAJERO");
    }
}
