package com.bodega.backend.controller;

import com.bodega.backend.dto.ActualizarBodegaDTO;
import com.bodega.backend.dto.BodegaDTO;
import com.bodega.backend.dto.ConfiguracionSunatDTO;
import com.bodega.backend.dto.PagoSuscripcionDTO;
import com.bodega.backend.dto.PagoYapeDTO;
import com.bodega.backend.service.BodegaService;
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
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class BodegaControllerTest {

    @Mock
    private BodegaService bodegaService;

    @InjectMocks
    private BodegaController bodegaController;

    private BodegaDTO bodegaDTO;

    @BeforeEach
    void setUp() {
        bodegaDTO = new BodegaDTO();
        bodegaDTO.setIdBodega(1L);
        bodegaDTO.setNombreComercial("Bodega Central");
        bodegaDTO.setRucDni("20100070970");
        bodegaDTO.setPlan("PRO");
        bodegaDTO.setEstado(true);
    }

    @Test
    void testObtenerMiBodega() {
        when(bodegaService.obtenerMiBodega()).thenReturn(bodegaDTO);

        ResponseEntity<BodegaDTO> response = bodegaController.obtenerMiBodega();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("Bodega Central", response.getBody().getNombreComercial());
    }

    @Test
    void testListarTodas() {
        when(bodegaService.listarTodas()).thenReturn(List.of(bodegaDTO));

        ResponseEntity<List<BodegaDTO>> response = bodegaController.listarTodas();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1, response.getBody().size());
    }

    @Test
    void testObtenerPorId() {
        when(bodegaService.obtenerPorId(1L)).thenReturn(bodegaDTO);

        ResponseEntity<BodegaDTO> response = bodegaController.obtenerPorId(1L);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1L, response.getBody().getIdBodega());
    }

    @Test
    void testActualizarConfiguracion() {
        ActualizarBodegaDTO dto = new ActualizarBodegaDTO();
        dto.setNombreComercial("Bodega Central VIP");

        when(bodegaService.actualizarConfiguracion(any(ActualizarBodegaDTO.class))).thenReturn(bodegaDTO);

        ResponseEntity<BodegaDTO> response = bodegaController.actualizarConfiguracion(dto);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(bodegaService).actualizarConfiguracion(any(ActualizarBodegaDTO.class));
    }

    @Test
    void testRegistrarPagoYape() {
        PagoYapeDTO dto = new PagoYapeDTO();
        dto.setCodigoOperacion("12345678");
        dto.setPlan("PRO");
        dto.setMonto(new BigDecimal("49.00"));
        dto.setBilletera("YAPE");

        when(bodegaService.registrarPagoYape(any(PagoYapeDTO.class))).thenReturn(bodegaDTO);

        ResponseEntity<BodegaDTO> response = bodegaController.registrarPagoYape(dto);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(bodegaService).registrarPagoYape(any(PagoYapeDTO.class));
    }

    @Test
    void testActualizarConfiguracionSunat() {
        ConfiguracionSunatDTO dto = new ConfiguracionSunatDTO();
        dto.setFacturacionSunatActiva(true);

        when(bodegaService.actualizarConfiguracionSunat(any(ConfiguracionSunatDTO.class))).thenReturn(bodegaDTO);

        ResponseEntity<BodegaDTO> response = bodegaController.actualizarConfiguracionSunat(dto);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(bodegaService).actualizarConfiguracionSunat(any(ConfiguracionSunatDTO.class));
    }

    @Test
    void testListarMisPagos() {
        PagoSuscripcionDTO pago = new PagoSuscripcionDTO();
        pago.setIdPago(100L);
        pago.setCodigoOperacion("12345678");

        when(bodegaService.listarMisPagos()).thenReturn(List.of(pago));

        ResponseEntity<List<PagoSuscripcionDTO>> response = bodegaController.listarMisPagos();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1, response.getBody().size());
    }

    @Test
    void testListarTodosLosPagos() {
        PagoSuscripcionDTO pago = new PagoSuscripcionDTO();
        pago.setIdPago(101L);

        when(bodegaService.listarTodosLosPagos()).thenReturn(List.of(pago));

        ResponseEntity<List<PagoSuscripcionDTO>> response = bodegaController.listarTodosLosPagos();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1, response.getBody().size());
    }
}
