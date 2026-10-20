package com.bodega.backend.controller;

import com.bodega.backend.dto.CompraDTO;
import com.bodega.backend.service.CompraService;
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
public class CompraControllerTest {

    @Mock
    private CompraService compraService;

    @InjectMocks
    private CompraController compraController;

    private CompraDTO compraDTO;

    @BeforeEach
    void setUp() {
        compraDTO = new CompraDTO();
        compraDTO.setIdCompra(1L);
        compraDTO.setIdProveedor(10L);
        compraDTO.setComprobante("F001-000456");
        compraDTO.setTotal(new BigDecimal("350.00"));
    }

    @Test
    void testListarTodas() {
        when(compraService.listarTodas()).thenReturn(List.of(compraDTO));

        ResponseEntity<List<CompraDTO>> response = compraController.listarTodas();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1, response.getBody().size());
        assertEquals(new BigDecimal("350.00"), response.getBody().get(0).getTotal());
    }

    @Test
    void testRegistrarCompra() {
        when(compraService.registrarCompra(any(CompraDTO.class))).thenReturn(compraDTO);

        ResponseEntity<CompraDTO> response = compraController.registrarCompra(compraDTO);

        assertNotNull(response);
        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertEquals(1L, response.getBody().getIdCompra());
        verify(compraService).registrarCompra(any(CompraDTO.class));
    }
}
