package com.bodega.backend.controller;

import com.bodega.backend.dto.PedidoWebDTO;
import com.bodega.backend.dto.RevisionPedidosDTO;
import com.bodega.backend.service.PedidoWebService;
import com.bodega.backend.service.TenantService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PedidoWebControllerTest {

    @Mock
    private PedidoWebService pedidoWebService;

    @Mock
    private TenantService tenantService;

    @InjectMocks
    private PedidoWebController controller;

    @BeforeEach
    void setUp() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
    }

    @Test
    void testConsultarRevisionRetornaStatusOk() {
        RevisionPedidosDTO mockRev = RevisionPedidosDTO.builder()
                .hayCambio(true)
                .revision(5L)
                .conteoPendientes(2L)
                .timestamp(System.currentTimeMillis())
                .build();

        when(pedidoWebService.verificarRevision(1L, 2L)).thenReturn(mockRev);

        ResponseEntity<RevisionPedidosDTO> resp = controller.consultarRevision(2L);
        assertEquals(200, resp.getStatusCode().value());
        assertNotNull(resp.getBody());
        assertTrue(resp.getBody().isHayCambio());
        assertEquals(5L, resp.getBody().getRevision());
        assertEquals(2L, resp.getBody().getConteoPendientes());
    }

    @Test
    void testListarPedidosRetornaLista() {
        PedidoWebDTO p = PedidoWebDTO.builder()
                .idPedidoWeb(1L)
                .codigoPedido("#W-1001")
                .nombreCliente("Juan")
                .total(new BigDecimal("12.00"))
                .estado("PENDIENTE")
                .build();

        when(pedidoWebService.listarPedidos(1L, "PENDIENTE", 50)).thenReturn(List.of(p));

        ResponseEntity<List<PedidoWebDTO>> resp = controller.listarPedidos("PENDIENTE", 50);
        assertEquals(200, resp.getStatusCode().value());
        assertNotNull(resp.getBody());
        assertEquals(1, resp.getBody().size());
        assertEquals("#W-1001", resp.getBody().get(0).getCodigoPedido());
    }

    @Test
    void testActualizarEstadoRetornaActualizado() {
        PedidoWebDTO p = PedidoWebDTO.builder()
                .idPedidoWeb(1L)
                .codigoPedido("#W-1001")
                .estado("CARGADO_EN_POS")
                .build();

        when(pedidoWebService.actualizarEstado(1L, 1L, "CARGADO_EN_POS")).thenReturn(p);

        ResponseEntity<PedidoWebDTO> resp = controller.actualizarEstado(1L, "CARGADO_EN_POS");
        assertEquals(200, resp.getStatusCode().value());
        assertNotNull(resp.getBody());
        assertEquals("CARGADO_EN_POS", resp.getBody().getEstado());
    }

    @Test
    void testEliminarPedidoRetornaMensaje() {
        doNothing().when(pedidoWebService).eliminarPedido(1L, 10L);

        ResponseEntity<Map<String, Object>> resp = controller.eliminarPedido(10L);
        assertEquals(200, resp.getStatusCode().value());
        assertNotNull(resp.getBody());
        assertTrue(resp.getBody().containsKey("mensaje"));
    }
}
