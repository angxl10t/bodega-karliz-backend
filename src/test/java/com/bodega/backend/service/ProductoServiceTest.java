package com.bodega.backend.service;

import com.bodega.backend.dto.ProductoDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Categoria;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.MovimientoInventarioRepository;
import com.bodega.backend.repository.PresentacionRepository;
import com.bodega.backend.repository.ProductoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class ProductoServiceTest {

    @Mock
    private ProductoRepository productoRepository;

    @Mock
    private CategoriaRepository categoriaRepository;

    @Mock
    private MovimientoInventarioRepository movimientoInventarioRepository;

    @Mock
    private PresentacionRepository presentacionRepository;

    @Mock
    private TenantService tenantService;

    @InjectMocks
    private ProductoService productoService;

    private Bodega bodega;
    private Categoria categoria;
    private Producto producto;

    @BeforeEach
    void setUp() {
        bodega = new Bodega();
        bodega.setIdBodega(3L);
        bodega.setNombreComercial("Bodega KARLIZ");
        bodega.setPlan("BASICO");

        categoria = new Categoria();
        categoria.setIdCategoria(10L);
        categoria.setNombre("Bebidas");
        categoria.setBodega(bodega);
        categoria.setEstado(true);

        producto = new Producto();
        producto.setIdProducto(100L);
        producto.setNombre("Inca Kola 500ml");
        producto.setCodigo("BEB-0001");
        producto.setPrecioVenta(new BigDecimal("3.50"));
        producto.setStockActual(new BigDecimal("50.0"));
        producto.setStockMinimo(new BigDecimal("5.0"));
        producto.setEstado(true);
        producto.setBodega(bodega);
        producto.setCategoria(categoria);
    }

    @Test
    void testObtenerPorId_Exitoso() {
        when(tenantService.getCurrentBodegaId()).thenReturn(3L);
        when(productoRepository.findByIdProductoAndBodega_IdBodega(100L, 3L)).thenReturn(Optional.of(producto));

        ProductoDTO dto = productoService.obtenerPorId(100L);

        assertNotNull(dto);
        assertEquals(100L, dto.getIdProducto());
        assertEquals("Inca Kola 500ml", dto.getNombre());
        assertEquals(new BigDecimal("3.50"), dto.getPrecioVenta());
        assertEquals("Bebidas", dto.getNombreCategoria());
        verify(productoRepository, times(1)).findByIdProductoAndBodega_IdBodega(100L, 3L);
    }

    @Test
    void testObtenerPorId_NoEncontrado_LanzaExcepcion() {
        when(tenantService.getCurrentBodegaId()).thenReturn(3L);
        when(productoRepository.findByIdProductoAndBodega_IdBodega(999L, 3L)).thenReturn(Optional.empty());

        RuntimeException ex = assertThrows(RuntimeException.class, () -> productoService.obtenerPorId(999L));
        assertTrue(ex.getMessage().contains("Producto no encontrado con ID: 999"));
    }

    @Test
    void testCrear_PlanBasico_ExcedeCuota150_LanzaExcepcion() {
        when(tenantService.getCurrentBodegaId()).thenReturn(3L);
        when(tenantService.getCurrentBodega()).thenReturn(bodega);
        when(productoRepository.countByBodega_IdBodegaAndEstadoTrue(3L)).thenReturn(150L);

        ProductoDTO dto = new ProductoDTO();
        dto.setIdCategoria(10L);
        dto.setNombre("Nuevo Producto");
        dto.setPrecioVenta(new BigDecimal("5.00"));
        dto.setStockActual(new BigDecimal("10.0"));
        dto.setStockMinimo(new BigDecimal("2.0"));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> productoService.crear(dto));
        assertTrue(ex.getMessage().contains("Has alcanzado el límite de 150 productos"));
        verify(productoRepository, never()).save(any());
    }

    @Test
    void testCrear_PlanBasico_DentroDeCuota_Exitoso() {
        when(tenantService.getCurrentBodegaId()).thenReturn(3L);
        when(tenantService.getCurrentBodega()).thenReturn(bodega);
        when(productoRepository.countByBodega_IdBodegaAndEstadoTrue(3L)).thenReturn(40L);
        when(categoriaRepository.findByIdCategoriaAndBodega_IdBodega(10L, 3L)).thenReturn(Optional.of(categoria));
        when(productoRepository.save(any(Producto.class))).thenAnswer(inv -> {
            Producto p = inv.getArgument(0);
            p.setIdProducto(200L);
            return p;
        });

        ProductoDTO dto = new ProductoDTO();
        dto.setIdCategoria(10L);
        dto.setCodigo("BEB-0005");
        dto.setNombre("Agua San Luis 625ml");
        dto.setPrecioVenta(new BigDecimal("2.00"));
        dto.setStockActual(new BigDecimal("24.0"));
        dto.setStockMinimo(new BigDecimal("6.0"));

        ProductoDTO creado = productoService.crear(dto);

        assertNotNull(creado);
        assertEquals("Agua San Luis 625ml", creado.getNombre());
        verify(productoRepository).save(any(Producto.class));
    }
}
