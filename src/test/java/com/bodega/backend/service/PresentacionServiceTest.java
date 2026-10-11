package com.bodega.backend.service;

import com.bodega.backend.dto.PresentacionDTO;
import com.bodega.backend.entity.Presentacion;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.PresentacionRepository;
import com.bodega.backend.repository.ProductoRepository;
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
public class PresentacionServiceTest {

    @Mock
    private PresentacionRepository presentacionRepository;

    @Mock
    private ProductoRepository productoRepository;

    @InjectMocks
    private PresentacionService presentacionService;

    @Test
    void testCrearPresentacion_Exito() {
        // 1. Preparar datos falsos simulados (Mocks)
        Producto mockProducto = new Producto();
        mockProducto.setIdProducto(1L);
        mockProducto.setNombre("Coca Cola 3L");

        PresentacionDTO dtoInput = new PresentacionDTO();
        dtoInput.setIdProducto(1L);
        dtoInput.setNombre("Caja x 6");
        dtoInput.setFactorConversion(new BigDecimal("6.000"));

        Presentacion mockGuardado = new Presentacion();
        mockGuardado.setIdPresentacion(10L);
        mockGuardado.setProducto(mockProducto);
        mockGuardado.setNombre("Caja x 6");
        mockGuardado.setFactorConversion(new BigDecimal("6.000"));
        mockGuardado.setEstado(true);

        // Simulamos que la base de datos encuentra el producto y guarda la presentación
        when(productoRepository.findById(1L)).thenReturn(Optional.of(mockProducto));
        when(presentacionRepository.save(any(Presentacion.class))).thenReturn(mockGuardado);

        // 2. Ejecutar la función real
        PresentacionDTO resultado = presentacionService.crear(dtoInput);

        // 3. Verificar que el resultado es el esperado
        assertNotNull(resultado);
        assertEquals(10L, resultado.getIdPresentacion());
        assertEquals("Caja x 6", resultado.getNombre());
        assertEquals("Coca Cola 3L", resultado.getNombreProducto());
        
        // Verificar que el repositorio fue llamado exactamente una vez
        verify(productoRepository, times(1)).findById(1L);
        verify(presentacionRepository, times(1)).save(any(Presentacion.class));
    }
}
