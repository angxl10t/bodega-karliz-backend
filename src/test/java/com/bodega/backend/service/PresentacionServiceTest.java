package com.bodega.backend.service;

import com.bodega.backend.dto.PresentacionDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Presentacion;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.PresentacionRepository;
import com.bodega.backend.repository.ProductoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class PresentacionServiceTest {

    @Mock
    private PresentacionRepository presentacionRepository;

    @Mock
    private ProductoRepository productoRepository;

    @Mock
    private TenantService tenantService;

    @InjectMocks
    private PresentacionService presentacionService;

    private Bodega bodega;
    private Producto producto;
    private Presentacion presentacion;

    @BeforeEach
    void setUp() {
        bodega = new Bodega();
        bodega.setIdBodega(1L);

        producto = new Producto();
        producto.setIdProducto(5L);
        producto.setNombre("Inca Kola 3L");
        producto.setBodega(bodega);
        producto.setEstado(true);

        presentacion = new Presentacion();
        presentacion.setIdPresentacion(10L);
        presentacion.setProducto(producto);
        presentacion.setNombre("Paquete x 4");
        presentacion.setFactorConversion(new BigDecimal("4.000"));
        presentacion.setBodega(bodega);
        presentacion.setEstado(true);
    }

    @Test
    void testListarPorProducto_Exito() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(productoRepository.findByIdProductoAndBodega_IdBodega(5L, 1L)).thenReturn(Optional.of(producto));
        when(presentacionRepository.findByProducto_IdProductoAndProducto_Bodega_IdBodegaAndEstadoTrue(5L, 1L))
                .thenReturn(List.of(presentacion));

        List<PresentacionDTO> resultado = presentacionService.listarPorProducto(5L);

        assertNotNull(resultado);
        assertEquals(1, resultado.size());
        assertEquals("Paquete x 4", resultado.get(0).getNombre());
    }

    @Test
    void testCrearPresentacion_Exito() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(productoRepository.findByIdProductoAndBodega_IdBodega(5L, 1L)).thenReturn(Optional.of(producto));
        when(presentacionRepository.findByProducto_IdProductoAndNombreIgnoreCase(5L, "Six-Pack"))
                .thenReturn(Optional.empty());

        Presentacion mockGuardado = new Presentacion();
        mockGuardado.setIdPresentacion(20L);
        mockGuardado.setProducto(producto);
        mockGuardado.setNombre("Six-Pack");
        mockGuardado.setFactorConversion(new BigDecimal("6.000"));
        mockGuardado.setEstado(true);

        when(presentacionRepository.save(any(Presentacion.class))).thenReturn(mockGuardado);

        PresentacionDTO input = new PresentacionDTO();
        input.setIdProducto(5L);
        input.setNombre("Six-Pack");
        input.setFactorConversion(new BigDecimal("6.000"));

        PresentacionDTO resultado = presentacionService.crear(input);

        assertNotNull(resultado);
        assertEquals(20L, resultado.getIdPresentacion());
        assertEquals("Six-Pack", resultado.getNombre());
        verify(presentacionRepository).save(any(Presentacion.class));
    }

    @Test
    void testCrearPresentacion_FactorInvalido_LanzaExcepcion() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(productoRepository.findByIdProductoAndBodega_IdBodega(5L, 1L)).thenReturn(Optional.of(producto));

        PresentacionDTO input = new PresentacionDTO();
        input.setIdProducto(5L);
        input.setNombre("Caja");
        input.setFactorConversion(BigDecimal.ZERO);

        RuntimeException ex = assertThrows(RuntimeException.class, () -> presentacionService.crear(input));
        assertTrue(ex.getMessage().contains("mayor a 0"));
    }

    @Test
    void testActualizarPresentacion_Exito() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(presentacionRepository.findByIdPresentacionAndProducto_Bodega_IdBodega(10L, 1L))
                .thenReturn(Optional.of(presentacion));
        when(presentacionRepository.findByProducto_IdProductoAndNombreIgnoreCase(5L, "Paquete Familiar x 4"))
                .thenReturn(Optional.empty());
        when(presentacionRepository.save(any(Presentacion.class))).thenAnswer(inv -> inv.getArgument(0));

        PresentacionDTO dto = new PresentacionDTO();
        dto.setNombre("Paquete Familiar x 4");
        dto.setFactorConversion(new BigDecimal("4.000"));

        PresentacionDTO actualizado = presentacionService.actualizar(10L, dto);

        assertNotNull(actualizado);
        assertEquals("Paquete Familiar x 4", actualizado.getNombre());
    }

    @Test
    void testDesactivarPresentacion_Exito() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(presentacionRepository.findByIdPresentacionAndProducto_Bodega_IdBodega(10L, 1L))
                .thenReturn(Optional.of(presentacion));

        presentacionService.desactivar(10L);

        assertFalse(presentacion.getEstado());
        verify(presentacionRepository).save(presentacion);
    }
}
