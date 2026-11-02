package com.bodega.backend.service;

import com.bodega.backend.dto.DevolverGarantiaDTO;
import com.bodega.backend.dto.GarantiaBotellaDTO;
import com.bodega.backend.dto.RegistrarGarantiaDTO;
import com.bodega.backend.dto.ResumenGarantiasDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Cliente;
import com.bodega.backend.entity.GarantiaBotella;
import com.bodega.backend.exception.ResourceNotFoundException;
import com.bodega.backend.repository.ClienteRepository;
import com.bodega.backend.repository.GarantiaBotellaRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class GarantiaBotellaServiceTest {

    @Mock
    private GarantiaBotellaRepository garantiaRepository;

    @Mock
    private ClienteRepository clienteRepository;

    @Mock
    private TenantService tenantService;

    @InjectMocks
    private GarantiaBotellaService garantiaService;

    private Bodega bodegaTest;
    private GarantiaBotella garantiaTest;

    @BeforeEach
    void setUp() {
        bodegaTest = new Bodega();
        bodegaTest.setIdBodega(1L);
        bodegaTest.setNombreComercial("Bodega KARLIZ");

        garantiaTest = new GarantiaBotella();
        garantiaTest.setIdGarantia(10L);
        garantiaTest.setBodega(bodegaTest);
        garantiaTest.setNombrePersona("Don Pedro Vecino");
        garantiaTest.setTelefono("987654321");
        garantiaTest.setCantidadBotellas(3);
        garantiaTest.setMontoGarantia(new BigDecimal("6.00")); // S/ 2.00 por botella
        garantiaTest.setTipoBotella("Cerveza 650ml");
        garantiaTest.setEstado("PENDIENTE");
        garantiaTest.setBotellasDevueltas(0);
        garantiaTest.setMontoDevuelto(BigDecimal.ZERO);
        garantiaTest.setFechaRegistro(OffsetDateTime.now());
    }

    @Test
    void testCrearGarantiaExitosamente() {
        when(tenantService.getCurrentBodega()).thenReturn(bodegaTest);
        when(garantiaRepository.save(any(GarantiaBotella.class))).thenAnswer(invocation -> {
            GarantiaBotella g = invocation.getArgument(0);
            g.setIdGarantia(15L);
            return g;
        });

        RegistrarGarantiaDTO dto = RegistrarGarantiaDTO.builder()
                .nombrePersona("María Quispe")
                .telefono("999888777")
                .cantidadBotellas(2)
                .montoGarantia(new BigDecimal("4.00"))
                .tipoBotella("Gaseosa 1L Vidrio")
                .notas("Vecina de la esquina")
                .build();

        GarantiaBotellaDTO res = garantiaService.crear(dto);

        assertNotNull(res);
        assertEquals(15L, res.getIdGarantia());
        assertEquals("María Quispe", res.getNombrePersona());
        assertEquals(2, res.getCantidadBotellas());
        assertEquals(new BigDecimal("4.00"), res.getMontoGarantia());
        assertEquals(2, res.getBotellasRestantes());
        assertEquals(new BigDecimal("4.00"), res.getMontoRestante());
        assertEquals("PENDIENTE", res.getEstado());

        verify(garantiaRepository, times(1)).save(any(GarantiaBotella.class));
    }

    @Test
    void testDevolverGarantiaTotalmenteYEntregarDinero() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(garantiaRepository.findByIdGarantiaAndBodega_IdBodega(10L, 1L))
                .thenReturn(Optional.of(garantiaTest));
        when(garantiaRepository.save(any(GarantiaBotella.class))).thenAnswer(i -> i.getArgument(0));

        DevolverGarantiaDTO dto = DevolverGarantiaDTO.builder()
                .cantidadDevolver(3)
                .montoEntregado(new BigDecimal("6.00"))
                .notas("Devolvió todas las botellas intactas")
                .build();

        GarantiaBotellaDTO res = garantiaService.devolver(10L, dto);

        assertEquals("DEVUELTO", res.getEstado());
        assertEquals(3, res.getBotellasDevueltas());
        assertEquals(0, res.getBotellasRestantes());
        assertEquals(new BigDecimal("6.00"), res.getMontoDevuelto());
        assertEquals(0, res.getMontoRestante().compareTo(BigDecimal.ZERO));
        assertNotNull(res.getFechaDevolucion());

        verify(garantiaRepository).save(garantiaTest);
    }

    @Test
    void testDevolverGarantiaParcial() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(garantiaRepository.findByIdGarantiaAndBodega_IdBodega(10L, 1L))
                .thenReturn(Optional.of(garantiaTest));
        when(garantiaRepository.save(any(GarantiaBotella.class))).thenAnswer(i -> i.getArgument(0));

        // Devuelve 1 botella de 3 pendientes (S/ 2.00)
        DevolverGarantiaDTO dto = DevolverGarantiaDTO.builder()
                .cantidadDevolver(1)
                .montoEntregado(new BigDecimal("2.00"))
                .notas("Devolvió 1 botella hoy")
                .build();

        GarantiaBotellaDTO res = garantiaService.devolver(10L, dto);

        assertEquals("PENDIENTE", res.getEstado());
        assertEquals(1, res.getBotellasDevueltas());
        assertEquals(2, res.getBotellasRestantes());
        assertEquals(new BigDecimal("2.00"), res.getMontoDevuelto());
        assertEquals(new BigDecimal("4.00"), res.getMontoRestante());
    }

    @Test
    void testObtenerResumenGarantias() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(garantiaRepository.findByBodega_IdBodegaAndEstadoOrderByFechaRegistroDesc(1L, "PENDIENTE"))
                .thenReturn(List.of(garantiaTest));
        when(garantiaRepository.findDevolucionesDesde(eq(1L), any(OffsetDateTime.class)))
                .thenReturn(Collections.emptyList());

        ResumenGarantiasDTO resumen = garantiaService.obtenerResumen();

        assertNotNull(resumen);
        assertEquals(new BigDecimal("6.00"), resumen.getTotalDineroCustodia());
        assertEquals(3, resumen.getBotellasPendientes());
        assertEquals(1L, resumen.getPersonasPendientes());
    }

    @Test
    void testEliminarGarantia() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(garantiaRepository.findByIdGarantiaAndBodega_IdBodega(10L, 1L))
                .thenReturn(Optional.of(garantiaTest));

        garantiaService.eliminar(10L);

        verify(garantiaRepository).delete(garantiaTest);
    }

    @Test
    void testGarantiaNoEncontradaLanzaExcepcion() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(garantiaRepository.findByIdGarantiaAndBodega_IdBodega(999L, 1L))
                .thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> garantiaService.obtenerPorId(999L));
    }
}
