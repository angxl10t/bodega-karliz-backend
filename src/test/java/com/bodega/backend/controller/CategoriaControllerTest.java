package com.bodega.backend.controller;

import com.bodega.backend.dto.CategoriaDTO;
import com.bodega.backend.service.CategoriaService;
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
public class CategoriaControllerTest {

    @Mock
    private CategoriaService categoriaService;

    @InjectMocks
    private CategoriaController categoriaController;

    private CategoriaDTO categoriaDTO;

    @BeforeEach
    void setUp() {
        categoriaDTO = new CategoriaDTO();
        categoriaDTO.setIdCategoria(1L);
        categoriaDTO.setNombre("Lácteos");
        categoriaDTO.setDescripcion("Leches y derivados");
        categoriaDTO.setEstado(true);
    }

    @Test
    void testListarActivas() {
        when(categoriaService.listarActivas()).thenReturn(List.of(categoriaDTO));

        ResponseEntity<List<CategoriaDTO>> response = categoriaController.listarActivas();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1, response.getBody().size());
        assertEquals("Lácteos", response.getBody().get(0).getNombre());
    }

    @Test
    void testCrear() {
        when(categoriaService.crear(any(CategoriaDTO.class))).thenReturn(categoriaDTO);

        ResponseEntity<CategoriaDTO> response = categoriaController.crear(categoriaDTO);

        assertNotNull(response);
        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertEquals(1L, response.getBody().getIdCategoria());
    }

    @Test
    void testActualizar() {
        when(categoriaService.actualizar(eq(1L), any(CategoriaDTO.class))).thenReturn(categoriaDTO);

        ResponseEntity<CategoriaDTO> response = categoriaController.actualizar(1L, categoriaDTO);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(categoriaService).actualizar(eq(1L), any(CategoriaDTO.class));
    }

    @Test
    void testDesactivar() {
        doNothing().when(categoriaService).desactivar(1L);

        ResponseEntity<Void> response = categoriaController.desactivar(1L);

        assertNotNull(response);
        assertEquals(HttpStatus.NO_CONTENT, response.getStatusCode());
        verify(categoriaService).desactivar(1L);
    }
}
