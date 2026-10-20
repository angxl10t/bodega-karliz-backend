package com.bodega.backend.controller;

import com.bodega.backend.dto.PresentacionDTO;
import com.bodega.backend.service.PresentacionService;
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
public class PresentacionControllerTest {

    @Mock
    private PresentacionService presentacionService;

    @InjectMocks
    private PresentacionController presentacionController;

    private PresentacionDTO presentacionDTO;

    @BeforeEach
    void setUp() {
        presentacionDTO = new PresentacionDTO();
        presentacionDTO.setIdPresentacion(1L);
        presentacionDTO.setIdProducto(10L);
        presentacionDTO.setNombre("Six-Pack");
        presentacionDTO.setFactorConversion(new BigDecimal("6.000"));
        presentacionDTO.setEstado(true);
    }

    @Test
    void testListarPorProducto() {
        when(presentacionService.listarPorProducto(10L)).thenReturn(List.of(presentacionDTO));

        ResponseEntity<List<PresentacionDTO>> response = presentacionController.listarPorProducto(10L);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1, response.getBody().size());
        assertEquals("Six-Pack", response.getBody().get(0).getNombre());
    }

    @Test
    void testCrear() {
        when(presentacionService.crear(any(PresentacionDTO.class))).thenReturn(presentacionDTO);

        ResponseEntity<PresentacionDTO> response = presentacionController.crear(presentacionDTO);

        assertNotNull(response);
        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertEquals(1L, response.getBody().getIdPresentacion());
    }

    @Test
    void testActualizar() {
        when(presentacionService.actualizar(eq(1L), any(PresentacionDTO.class))).thenReturn(presentacionDTO);

        ResponseEntity<PresentacionDTO> response = presentacionController.actualizar(1L, presentacionDTO);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(presentacionService).actualizar(eq(1L), any(PresentacionDTO.class));
    }

    @Test
    void testDesactivar() {
        doNothing().when(presentacionService).desactivar(1L);

        ResponseEntity<Void> response = presentacionController.desactivar(1L);

        assertNotNull(response);
        assertEquals(HttpStatus.NO_CONTENT, response.getStatusCode());
        verify(presentacionService).desactivar(1L);
    }
}
