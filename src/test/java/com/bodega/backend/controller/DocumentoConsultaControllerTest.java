package com.bodega.backend.controller;

import com.bodega.backend.dto.DniConsultaDTO;
import com.bodega.backend.dto.RucConsultaDTO;
import com.bodega.backend.service.DocumentoConsultaService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class DocumentoConsultaControllerTest {

    @Mock
    private DocumentoConsultaService documentoService;

    @InjectMocks
    private DocumentoConsultaController documentoController;

    @Test
    void testConsultarDni() {
        DniConsultaDTO dto = DniConsultaDTO.builder()
                .numero("71234567")
                .nombreCompleto("JUAN PEREZ")
                .encontrado(true)
                .build();

        when(documentoService.consultarDni("71234567")).thenReturn(dto);

        ResponseEntity<DniConsultaDTO> response = documentoController.consultarDni("71234567");

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("71234567", response.getBody().getNumero());
        assertEquals("JUAN PEREZ", response.getBody().getNombreCompleto());
    }

    @Test
    void testConsultarRuc() {
        RucConsultaDTO dto = RucConsultaDTO.builder()
                .numero("20100070970")
                .razonSocial("SUPERINTENDENCIA NACIONAL DE ADUANAS Y DE ADMINISTRACION TRIBUTARIA")
                .esActivo(true)
                .esHabido(true)
                .build();

        when(documentoService.consultarRuc("20100070970")).thenReturn(dto);

        ResponseEntity<RucConsultaDTO> response = documentoController.consultarRuc("20100070970");

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("20100070970", response.getBody().getNumero());
        assertTrue(response.getBody().isEsActivo());
    }
}
