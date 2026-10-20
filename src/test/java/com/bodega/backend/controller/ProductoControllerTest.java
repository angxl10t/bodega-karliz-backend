package com.bodega.backend.controller;

import com.bodega.backend.dto.ProductoDTO;
import com.bodega.backend.service.ProductoService;
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
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class ProductoControllerTest {

    @Mock
    private ProductoService productoService;

    @InjectMocks
    private ProductoController productoController;

    private ProductoDTO productoDTO;

    @BeforeEach
    void setUp() {
        productoDTO = new ProductoDTO();
        productoDTO.setIdProducto(10L);
        productoDTO.setCodigo("LAC-0001");
        productoDTO.setNombre("Leche Gloria Azul 400g");
        productoDTO.setPrecioVenta(new BigDecimal("4.20"));
        productoDTO.setStockActual(new BigDecimal("24.000"));
        productoDTO.setStockMinimo(new BigDecimal("6.000"));
    }

    @Test
    void testListarActivos() {
        when(productoService.listarActivos()).thenReturn(List.of(productoDTO));

        ResponseEntity<List<ProductoDTO>> response = productoController.listarActivos();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1, response.getBody().size());
        assertEquals("LAC-0001", response.getBody().get(0).getCodigo());
    }

    @Test
    void testSiguienteCodigo() {
        when(productoService.generarSiguienteCodigo(1L)).thenReturn("LAC-0002");

        ResponseEntity<Map<String, String>> response = productoController.siguienteCodigo(1L);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("LAC-0002", response.getBody().get("codigo"));
    }

    @Test
    void testObtenerPorId() {
        when(productoService.obtenerPorId(10L)).thenReturn(productoDTO);

        ResponseEntity<ProductoDTO> response = productoController.obtenerPorId(10L);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(10L, response.getBody().getIdProducto());
    }

    @Test
    void testCrear() {
        when(productoService.crear(any(ProductoDTO.class))).thenReturn(productoDTO);

        ResponseEntity<ProductoDTO> response = productoController.crear(productoDTO);

        assertNotNull(response);
        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertEquals("Leche Gloria Azul 400g", response.getBody().getNombre());
    }

    @Test
    void testActualizar() {
        when(productoService.actualizar(eq(10L), any(ProductoDTO.class))).thenReturn(productoDTO);

        ResponseEntity<ProductoDTO> response = productoController.actualizar(10L, productoDTO);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(productoService).actualizar(eq(10L), any(ProductoDTO.class));
    }

    @Test
    void testDesactivar() {
        doNothing().when(productoService).desactivar(10L);

        ResponseEntity<Void> response = productoController.desactivar(10L);

        assertNotNull(response);
        assertEquals(HttpStatus.NO_CONTENT, response.getStatusCode());
        verify(productoService).desactivar(10L);
    }
}
