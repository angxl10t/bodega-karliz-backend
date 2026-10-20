package com.bodega.backend.controller;

import com.bodega.backend.dto.MovimientoInventarioDTO;
import com.bodega.backend.service.MovimientoService;
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

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class MovimientoControllerTest {

    @Mock
    private MovimientoService movimientoService;

    @InjectMocks
    private MovimientoController movimientoController;

    private MovimientoInventarioDTO movDTO;

    @BeforeEach
    void setUp() {
        movDTO = new MovimientoInventarioDTO();
        movDTO.setIdMovimiento(100L);
        movDTO.setIdProducto(10L);
        movDTO.setNombreProducto("Arroz Extra 1kg");
        movDTO.setTipoMovimiento("ENTRADA");
        movDTO.setCantidad(new BigDecimal("20.000"));
        movDTO.setMotivo("Inventario Inicial");
    }

    @Test
    void testListarTodos() {
        when(movimientoService.listarTodos()).thenReturn(List.of(movDTO));

        ResponseEntity<List<MovimientoInventarioDTO>> response = movimientoController.listarTodos();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1, response.getBody().size());
        assertEquals("Arroz Extra 1kg", response.getBody().get(0).getNombreProducto());
    }

    @Test
    void testListarPorProducto() {
        when(movimientoService.listarPorProducto(10L)).thenReturn(List.of(movDTO));

        ResponseEntity<List<MovimientoInventarioDTO>> response = movimientoController.listarPorProducto(10L);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1, response.getBody().size());
        assertEquals(10L, response.getBody().get(0).getIdProducto());
    }
}
