package com.bodega.backend.controller;

import com.bodega.backend.dto.ProveedorDTO;
import com.bodega.backend.service.ProveedorService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class ProveedorControllerTest {

    @Mock
    private ProveedorService proveedorService;

    @InjectMocks
    private ProveedorController proveedorController;

    private ProveedorDTO proveedorDTO;

    @BeforeEach
    void setUp() {
        proveedorDTO = new ProveedorDTO();
        proveedorDTO.setIdProveedor(5L);
        proveedorDTO.setRuc("20100070970");
        proveedorDTO.setRazonSocial("Distribuidora Gloria S.A.");
        proveedorDTO.setEstado(true);
    }

    @Test
    void testListarActivos() {
        when(proveedorService.listarActivos()).thenReturn(List.of(proveedorDTO));

        ResponseEntity<List<ProveedorDTO>> response = proveedorController.listarActivos();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1, response.getBody().size());
        assertEquals("Distribuidora Gloria S.A.", response.getBody().get(0).getRazonSocial());
    }

    @Test
    void testCrear() {
        when(proveedorService.crear(any(ProveedorDTO.class))).thenReturn(proveedorDTO);

        ResponseEntity<ProveedorDTO> response = proveedorController.crear(proveedorDTO);

        assertNotNull(response);
        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertEquals(5L, response.getBody().getIdProveedor());
    }

    @Test
    void testActualizar() {
        when(proveedorService.actualizar(eq(5L), any(ProveedorDTO.class))).thenReturn(proveedorDTO);

        ResponseEntity<ProveedorDTO> response = proveedorController.actualizar(5L, proveedorDTO);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(proveedorService).actualizar(eq(5L), any(ProveedorDTO.class));
    }

    @Test
    void testDesactivar() {
        doNothing().when(proveedorService).desactivar(5L);

        ResponseEntity<Void> response = proveedorController.desactivar(5L);

        assertNotNull(response);
        assertEquals(HttpStatus.NO_CONTENT, response.getStatusCode());
        verify(proveedorService).desactivar(5L);
    }
}
