package com.bodega.backend.controller;

import com.bodega.backend.dto.CierreCajaDTO;
import com.bodega.backend.dto.VentaDTO;
import com.bodega.backend.service.VentaService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class VentaControllerTest {

    @Mock
    private VentaService ventaService;

    @InjectMocks
    private VentaController ventaController;

    private VentaDTO ventaDTO;

    @BeforeEach
    void setUp() {
        ventaDTO = new VentaDTO();
        ventaDTO.setIdVenta(1L);
        ventaDTO.setTotal(new BigDecimal("25.50"));
        ventaDTO.setTipoComprobante("BOLETA");
        ventaDTO.setMetodoPago("Efectivo");
        ventaDTO.setEstado("COMPLETADA");
    }

    @Test
    void testListarTodas() {
        when(ventaService.listarTodas()).thenReturn(List.of(ventaDTO));

        ResponseEntity<List<VentaDTO>> response = ventaController.listarTodas();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1, response.getBody().size());
        assertEquals(new BigDecimal("25.50"), response.getBody().get(0).getTotal());
    }

    @Test
    void testObtenerCierreCajaHoy() {
        CierreCajaDTO cierre = new CierreCajaDTO();
        cierre.setFecha(OffsetDateTime.now());
        cierre.setTotalVentas(new BigDecimal("150.00"));
        cierre.setCantidadVentas(5);

        when(ventaService.obtenerCierreCajaHoy()).thenReturn(cierre);

        ResponseEntity<CierreCajaDTO> response = ventaController.obtenerCierreCajaHoy();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(5, response.getBody().getCantidadVentas());
    }

    @Test
    void testObtenerCierrePorFecha() {
        LocalDate hoy = LocalDate.now();
        CierreCajaDTO cierre = new CierreCajaDTO();
        cierre.setTotalVentas(new BigDecimal("200.00"));

        when(ventaService.obtenerCierreCajaPorFecha(hoy)).thenReturn(cierre);

        ResponseEntity<CierreCajaDTO> response = ventaController.obtenerCierrePorFecha(hoy);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(new BigDecimal("200.00"), response.getBody().getTotalVentas());
    }

    @Test
    void testObtenerHistorialCierres() {
        CierreCajaDTO c1 = new CierreCajaDTO();
        c1.setTotalVentas(new BigDecimal("100.00"));

        when(ventaService.obtenerHistorialCierres(30)).thenReturn(List.of(c1));

        ResponseEntity<List<CierreCajaDTO>> response = ventaController.obtenerHistorialCierres(30);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1, response.getBody().size());
    }

    @Test
    void testRegistrarVenta() {
        when(ventaService.registrarVenta(any(VentaDTO.class))).thenReturn(ventaDTO);

        ResponseEntity<VentaDTO> response = ventaController.registrarVenta(ventaDTO);

        assertNotNull(response);
        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertEquals(1L, response.getBody().getIdVenta());
        verify(ventaService).registrarVenta(any(VentaDTO.class));
    }

    @Test
    void testAnularVenta() {
        doNothing().when(ventaService).anularVenta(1L, "Error de tipeo");

        ResponseEntity<Void> response = ventaController.anularVenta(1L, "Error de tipeo");

        assertNotNull(response);
        assertEquals(HttpStatus.NO_CONTENT, response.getStatusCode());
        verify(ventaService).anularVenta(1L, "Error de tipeo");
    }

    @Test
    void testReintentarSunat() {
        when(ventaService.reintentarEnvioSunat(1L)).thenReturn(ventaDTO);

        ResponseEntity<VentaDTO> response = ventaController.reintentarSunat(1L);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(ventaService).reintentarEnvioSunat(1L);
    }
}
