package com.bodega.backend.controller;

import com.bodega.backend.dto.BoletaConsolidadaDTO;
import com.bodega.backend.dto.RegistrarBoletaConsolidadaDTO;
import com.bodega.backend.dto.ResumenVentasMenoresDTO;
import com.bodega.backend.service.BoletaConsolidadaService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class BoletaConsolidadaControllerTest {

    @Mock
    private BoletaConsolidadaService boletaConsolidadaService;

    @InjectMocks
    private BoletaConsolidadaController boletaConsolidadaController;

    @Test
    void testObtenerSugerencia() {
        LocalDate fecha = LocalDate.of(2026, 11, 3);
        ResumenVentasMenoresDTO dto = ResumenVentasMenoresDTO.builder()
                .fecha(fecha)
                .yaRegistrada(false)
                .montoSugerido(new BigDecimal("60.00"))
                .cantidadOperacionesSugeridas(18)
                .build();

        when(boletaConsolidadaService.obtenerSugerencia(fecha)).thenReturn(dto);

        ResponseEntity<ResumenVentasMenoresDTO> response = boletaConsolidadaController.obtenerSugerencia(fecha);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals(new BigDecimal("60.00"), response.getBody().getMontoSugerido());
    }

    @Test
    void testRegistrarBoletaConsolidada() {
        RegistrarBoletaConsolidadaDTO req = RegistrarBoletaConsolidadaDTO.builder()
                .fecha(LocalDate.of(2026, 11, 3))
                .montoTotal(new BigDecimal("60.00"))
                .cantidadOperaciones(18)
                .serieCorrelativo("001-000456")
                .tipoEmision("TALONARIO_FISICO")
                .build();

        BoletaConsolidadaDTO resDto = BoletaConsolidadaDTO.builder()
                .idBoletaConsolidada(1L)
                .serieCorrelativo("001-000456")
                .montoTotal(new BigDecimal("60.00"))
                .build();

        when(boletaConsolidadaService.registrarBoletaConsolidada(req)).thenReturn(resDto);

        ResponseEntity<BoletaConsolidadaDTO> response = boletaConsolidadaController.registrarBoletaConsolidada(req);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals("001-000456", response.getBody().getSerieCorrelativo());
    }

    @Test
    void testListarHistorial() {
        when(boletaConsolidadaService.listarHistorial(30)).thenReturn(List.of());

        ResponseEntity<List<BoletaConsolidadaDTO>> response = boletaConsolidadaController.listarHistorial(30);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertTrue(response.getBody().isEmpty());
    }
}
