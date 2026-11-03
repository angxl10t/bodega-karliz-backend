package com.bodega.backend.service;

import com.bodega.backend.dto.*;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.PedidoWeb;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.PedidoWebRepository;
import com.bodega.backend.repository.ProductoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageRequest;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PedidoWebServiceTest {

    @Mock
    private PedidoWebRepository pedidoWebRepository;

    @Mock
    private ProductoRepository productoRepository;

    @InjectMocks
    private PedidoWebService service;

    private Bodega bodega;
    private Producto producto;

    @BeforeEach
    void setUp() {
        bodega = new Bodega();
        bodega.setIdBodega(1L);
        bodega.setNombreComercial("Bodega Karliz");

        producto = new Producto();
        producto.setIdProducto(100L);
        producto.setNombre("Inca Kola 500ml");
        producto.setPrecioVenta(new BigDecimal("3.50"));
    }

    @Test
    void testVerificarRevisionZeroDbHitCuandoCacheado() {
        when(pedidoWebRepository.countByBodegaIdBodegaAndEstado(1L, "PENDIENTE")).thenReturn(3L);

        // Primera llamada inicializa la caché de conteo
        RevisionPedidosDTO rev1 = service.verificarRevision(1L, 0L);
        assertNotNull(rev1);
        assertEquals(3L, rev1.getConteoPendientes());

        // Segunda llamada con misma o posterior revisión no debe volver a consultar DB
        RevisionPedidosDTO rev2 = service.verificarRevision(1L, rev1.getRevision());
        assertFalse(rev2.isHayCambio());
        assertEquals(3L, rev2.getConteoPendientes());

        // Verificar que count sólo se llamó 1 vez gracias a computeIfAbsent en memoria
        verify(pedidoWebRepository, times(1)).countByBodegaIdBodegaAndEstado(1L, "PENDIENTE");
    }

    @Test
    void testRegistrarPedidoWebPublicoGeneraCodigoEIncrementaRevision() {
        PedidoWebCreacionDTO dto = PedidoWebCreacionDTO.builder()
                .nombreCliente("María Flores")
                .telefonoCliente("999888777")
                .notas("Llego a las 5pm")
                .total(new BigDecimal("7.00"))
                .ahorroPromociones(new BigDecimal("1.00"))
                .incluyeRetornables(true)
                .items(List.of(
                        PedidoWebDetalleCreacionDTO.builder()
                                .idProducto(100L)
                                .nombre("Inca Kola 500ml")
                                .cantidad(new BigDecimal("2.0"))
                                .precioUnitario(new BigDecimal("3.50"))
                                .subtotal(new BigDecimal("7.00"))
                                .badge("PROMO")
                                .build()
                ))
                .build();

        when(productoRepository.findById(100L)).thenReturn(Optional.of(producto));
        when(pedidoWebRepository.save(any(PedidoWeb.class))).thenAnswer(inv -> {
            PedidoWeb p = inv.getArgument(0);
            p.setIdPedidoWeb(50L);
            p.setFechaCreacion(OffsetDateTime.now());
            return p;
        });

        PedidoWebDTO resultado = service.registrarPedidoWebPublico(bodega, dto);

        assertNotNull(resultado);
        assertEquals(50L, resultado.getIdPedidoWeb());
        assertNotNull(resultado.getCodigoPedido());
        assertTrue(resultado.getCodigoPedido().startsWith("#W-") || resultado.getCodigoPedido().startsWith("WEB-"));
        assertEquals("María Flores", resultado.getNombreCliente());
        assertEquals("PENDIENTE", resultado.getEstado());
        assertEquals(1, resultado.getItems().size());
        assertEquals("Inca Kola 500ml", resultado.getItems().get(0).getNombre());

        // Verificar que la revisión en memoria aumentó
        RevisionPedidosDTO rev = service.verificarRevision(1L, 0L);
        assertTrue(rev.isHayCambio());
        assertTrue(rev.getRevision() >= 1L);
    }

    @Test
    void testActualizarEstadoACargadoEnPos() {
        PedidoWeb pedidoExistente = PedidoWeb.builder()
                .idPedidoWeb(10L)
                .bodega(bodega)
                .codigoPedido("#W-1234")
                .nombreCliente("Pedro")
                .estado("PENDIENTE")
                .total(new BigDecimal("15.00"))
                .detalles(new ArrayList<>())
                .build();

        when(pedidoWebRepository.findByIdPedidoWebAndBodegaIdBodega(10L, 1L))
                .thenReturn(Optional.of(pedidoExistente));
        when(pedidoWebRepository.save(any(PedidoWeb.class))).thenAnswer(inv -> inv.getArgument(0));

        PedidoWebDTO actualizado = service.actualizarEstado(1L, 10L, "CARGADO_EN_POS");

        assertNotNull(actualizado);
        assertEquals("CARGADO_EN_POS", actualizado.getEstado());
        verify(pedidoWebRepository).save(any(PedidoWeb.class));
    }

    @Test
    void testListarPedidosFiltraPorEstado() {
        PedidoWeb p = PedidoWeb.builder()
                .idPedidoWeb(1L)
                .bodega(bodega)
                .codigoPedido("#W-1111")
                .nombreCliente("Ana")
                .estado("PENDIENTE")
                .total(new BigDecimal("20.00"))
                .build();

        when(pedidoWebRepository.findByBodegaIdBodegaAndEstadoOrderByFechaCreacionDesc(
                eq(1L), eq("PENDIENTE"), any(PageRequest.class)
        )).thenReturn(List.of(p));

        List<PedidoWebDTO> lista = service.listarPedidos(1L, "PENDIENTE", 10);
        assertEquals(1, lista.size());
        assertEquals("#W-1111", lista.get(0).getCodigoPedido());
    }

    @Test
    void testEliminarPedido() {
        PedidoWeb pedido = PedidoWeb.builder()
                .idPedidoWeb(20L)
                .bodega(bodega)
                .codigoPedido("#W-9999")
                .nombreCliente("Rosa")
                .estado("PENDIENTE")
                .build();

        when(pedidoWebRepository.findByIdPedidoWebAndBodegaIdBodega(20L, 1L))
                .thenReturn(Optional.of(pedido));

        service.eliminarPedido(1L, 20L);

        verify(pedidoWebRepository).delete(pedido);
    }
}
