package com.bodega.backend.controller;

import com.bodega.backend.dto.PedidoWebCreacionDTO;
import com.bodega.backend.dto.PedidoWebDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Categoria;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.PromocionRepository;
import com.bodega.backend.service.PedidoWebService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CatalogoPublicoControllerTest {

    @Mock
    private BodegaRepository bodegaRepository;

    @Mock
    private ProductoRepository productoRepository;

    @Mock
    private PromocionRepository promocionRepository;

    @Mock
    private PedidoWebService pedidoWebService;

    @InjectMocks
    private CatalogoPublicoController controller;

    private Bodega bodegaPro;
    private Bodega bodegaBasico;
    private Producto prod1;

    @BeforeEach
    void setUp() {
        bodegaPro = new Bodega();
        bodegaPro.setIdBodega(1L);
        bodegaPro.setNombreComercial("Bodega Karliz");
        bodegaPro.setTelefono("987654321");
        bodegaPro.setPlan("PRO");
        bodegaPro.setEstado(true);

        bodegaBasico = new Bodega();
        bodegaBasico.setIdBodega(2L);
        bodegaBasico.setNombreComercial("Bodega Don Pepe");
        bodegaBasico.setTelefono("911222333");
        bodegaBasico.setPlan("BASICO");
        bodegaBasico.setEstado(true);

        Categoria cat = new Categoria();
        cat.setIdCategoria(1L);
        cat.setNombre("Bebidas");

        prod1 = new Producto();
        prod1.setIdProducto(101L);
        prod1.setCodigo("7750106001");
        prod1.setNombre("Inca Kola 500ml");
        prod1.setPrecioVenta(new BigDecimal("3.50"));
        prod1.setStockActual(new BigDecimal("20.0"));
        prod1.setCategoria(cat);
        prod1.setEstado(true);
    }

    @Test
    void testCatalogoBodegaProRetornaProductos() {
        when(bodegaRepository.findFirstByOrderByIdBodegaAsc()).thenReturn(Optional.of(bodegaPro));
        when(productoRepository.findByBodega_IdBodegaAndEstadoTrue(1L)).thenReturn(List.of(prod1));

        ResponseEntity<Map<String, Object>> response = controller.obtenerCatalogoPorParam(null);

        assertEquals(200, response.getStatusCode().value());
        Map<String, Object> body = response.getBody();
        assertNotNull(body);
        assertTrue((Boolean) body.get("esPro"));
        assertEquals(1, body.get("totalProductos"));
        List<?> prods = (List<?>) body.get("productos");
        assertEquals(1, prods.size());
    }

    @Test
    void testCatalogoBodegaProOcultaProductosSinStock() {
        Producto prodAgotado = new Producto();
        prodAgotado.setIdProducto(102L);
        prodAgotado.setNombre("Galletas Oreo");
        prodAgotado.setStockActual(BigDecimal.ZERO);
        prodAgotado.setEstado(true);

        when(bodegaRepository.findFirstByOrderByIdBodegaAsc()).thenReturn(Optional.of(bodegaPro));
        when(productoRepository.findByBodega_IdBodegaAndEstadoTrue(1L)).thenReturn(List.of(prod1, prodAgotado));

        ResponseEntity<Map<String, Object>> response = controller.obtenerCatalogoPorParam(null);

        assertEquals(200, response.getStatusCode().value());
        Map<String, Object> body = response.getBody();
        assertNotNull(body);
        assertEquals(1, body.get("totalProductos"));
        List<?> prods = (List<?>) body.get("productos");
        assertEquals(1, prods.size());
    }

    @Test
    void testCatalogoBodegaBasicoBloqueaProductos() {
        when(bodegaRepository.findByEstadoTrueOrderByNombreComercialAsc()).thenReturn(List.of(bodegaBasico));

        ResponseEntity<Map<String, Object>> response = controller.obtenerCatalogoPorParam("bodega-don-pepe");

        assertEquals(200, response.getStatusCode().value());
        Map<String, Object> body = response.getBody();
        assertNotNull(body);
        assertFalse((Boolean) body.get("esPro"));
        assertNotNull(body.get("mensaje"));
        List<?> prods = (List<?>) body.get("productos");
        assertTrue(prods.isEmpty());
        verify(productoRepository, never()).findByBodega_IdBodegaAndEstadoTrue(anyLong());
    }

    @Test
    void testCatalogoBodegaProExpiradaBloqueaProductos() {
        bodegaPro.setFechaVencimientoPlan(OffsetDateTime.now().minusDays(1));
        when(bodegaRepository.findFirstByOrderByIdBodegaAsc()).thenReturn(Optional.of(bodegaPro));

        ResponseEntity<Map<String, Object>> response = controller.obtenerCatalogoPorParam(null);

        assertEquals(200, response.getStatusCode().value());
        Map<String, Object> body = response.getBody();
        assertNotNull(body);
        assertFalse((Boolean) body.get("esPro"));
        verify(productoRepository, never()).findByBodega_IdBodegaAndEstadoTrue(anyLong());
    }

    @Test
    void testCatalogoBodegaNoExistenteRetorna404() {
        when(bodegaRepository.findByEstadoTrueOrderByNombreComercialAsc()).thenReturn(List.of(bodegaPro));

        ResponseEntity<Map<String, Object>> response = controller.obtenerCatalogoPorParam("bodega-fantasma-999");

        assertEquals(404, response.getStatusCode().value());
        Map<String, Object> body = response.getBody();
        assertNotNull(body);
        assertEquals("Bodega no encontrada", body.get("error"));
        assertFalse((Boolean) body.get("esPro"));
        verify(productoRepository, never()).findByBodega_IdBodegaAndEstadoTrue(anyLong());
    }

    @Test
    void testRegistrarPedidoPublicoExitoso() {
        when(bodegaRepository.findFirstByOrderByIdBodegaAsc()).thenReturn(Optional.of(bodegaPro));
        PedidoWebCreacionDTO dto = PedidoWebCreacionDTO.builder()
                .nombreCliente("Carlos Gómez")
                .total(new BigDecimal("10.50"))
                .build();
        PedidoWebDTO mockRet = PedidoWebDTO.builder()
                .idPedidoWeb(1L)
                .codigoPedido("#W-1234")
                .nombreCliente("Carlos Gómez")
                .total(new BigDecimal("10.50"))
                .estado("PENDIENTE")
                .build();
        when(pedidoWebService.registrarPedidoWebPublico(eq(bodegaPro), any(PedidoWebCreacionDTO.class))).thenReturn(mockRet);

        ResponseEntity<?> resp = controller.registrarPedidoPublicoParam(null, dto);
        assertEquals(201, resp.getStatusCode().value());
        assertTrue(resp.getBody() instanceof PedidoWebDTO);
        PedidoWebDTO resDto = (PedidoWebDTO) resp.getBody();
        assertEquals("#W-1234", resDto.getCodigoPedido());
    }
}
