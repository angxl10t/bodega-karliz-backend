package com.bodega.backend.service;

import com.bodega.backend.dto.MovimientoInventarioDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.MovimientoInventario;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.MovimientoInventarioRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class MovimientoServiceTest {

    @Mock
    private MovimientoInventarioRepository movimientoRepository;

    @Mock
    private TenantService tenantService;

    @InjectMocks
    private MovimientoService movimientoService;

    private Bodega bodega;
    private Producto producto;
    private MovimientoInventario movimiento;

    @BeforeEach
    void setUp() {
        bodega = new Bodega();
        bodega.setIdBodega(1L);

        producto = new Producto();
        producto.setIdProducto(100L);
        producto.setNombre("Arroz Costeño 1kg");
        producto.setBodega(bodega);

        movimiento = new MovimientoInventario();
        movimiento.setIdMovimiento(1L);
        movimiento.setProducto(producto);
        movimiento.setTipoMovimiento("ENTRADA");
        movimiento.setCantidad(new BigDecimal("50.000"));
        movimiento.setMotivo("Compra a proveedor");
        movimiento.setFechaMovimiento(OffsetDateTime.now());
        movimiento.setUsuarioResponsable("admin");
        movimiento.setBodega(bodega);
    }

    @Test
    void testListarTodos() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(movimientoRepository.findTop200ByBodega_IdBodegaOrderByFechaMovimientoDesc(1L))
                .thenReturn(List.of(movimiento));

        List<MovimientoInventarioDTO> resultado = movimientoService.listarTodos();

        assertNotNull(resultado);
        assertEquals(1, resultado.size());
        assertEquals("Arroz Costeño 1kg", resultado.get(0).getNombreProducto());
        assertEquals("ENTRADA", resultado.get(0).getTipoMovimiento());
    }

    @Test
    void testListarPorProducto_IdValido() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(movimientoRepository.findTop100ByBodega_IdBodegaAndProducto_IdProductoOrderByFechaMovimientoDesc(1L, 100L))
                .thenReturn(List.of(movimiento));

        List<MovimientoInventarioDTO> resultado = movimientoService.listarPorProducto(100L);

        assertNotNull(resultado);
        assertEquals(1, resultado.size());
        assertEquals(100L, resultado.get(0).getIdProducto());
    }

    @Test
    void testListarPorProducto_IdInvalido_RetornaListaVacia() {
        List<MovimientoInventarioDTO> resNull = movimientoService.listarPorProducto(null);
        List<MovimientoInventarioDTO> resZero = movimientoService.listarPorProducto(0L);
        List<MovimientoInventarioDTO> resNeg = movimientoService.listarPorProducto(-5L);

        assertTrue(resNull.isEmpty());
        assertTrue(resZero.isEmpty());
        assertTrue(resNeg.isEmpty());
        verifyNoInteractions(tenantService);
        verifyNoInteractions(movimientoRepository);
    }
}
