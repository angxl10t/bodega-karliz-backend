package com.bodega.backend.service;

import com.bodega.backend.dto.BoletaConsolidadaDTO;
import com.bodega.backend.dto.RegistrarBoletaConsolidadaDTO;
import com.bodega.backend.dto.ResumenVentasMenoresDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.BoletaConsolidada;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.BoletaConsolidadaRepository;
import com.bodega.backend.repository.VentaRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class BoletaConsolidadaServiceTest {

    @Mock
    private BoletaConsolidadaRepository boletaConsolidadaRepository;

    @Mock
    private VentaRepository ventaRepository;

    @Mock
    private BodegaRepository bodegaRepository;

    @Mock
    private TenantService tenantService;

    @InjectMocks
    private BoletaConsolidadaService boletaConsolidadaService;

    private Bodega bodega;
    private final Long ID_BODEGA = 1L;

    @BeforeEach
    void setUp() {
        bodega = new Bodega();
        bodega.setIdBodega(ID_BODEGA);
        bodega.setNombreComercial("Bodega Karliz");
        bodega.setRegimenTributario("NUEVO_RUS");
    }

    @Test
    void testObtenerSugerencia_SinRegistroPrevio_CalculaVentasMenores() {
        when(tenantService.getCurrentBodegaId()).thenReturn(ID_BODEGA);
        LocalDate fecha = LocalDate.of(2026, 11, 3);

        when(boletaConsolidadaRepository.findByBodega_IdBodegaAndFechaEmision(ID_BODEGA, fecha))
                .thenReturn(Optional.empty());
        when(ventaRepository.sumVentasMenores(eq(ID_BODEGA), any(BigDecimal.class), any(OffsetDateTime.class), any(OffsetDateTime.class)))
                .thenReturn(new BigDecimal("74.50"));
        when(ventaRepository.countVentasMenores(eq(ID_BODEGA), any(BigDecimal.class), any(OffsetDateTime.class), any(OffsetDateTime.class)))
                .thenReturn(23L);

        ResumenVentasMenoresDTO resumen = boletaConsolidadaService.obtenerSugerencia(fecha);

        assertNotNull(resumen);
        assertEquals(fecha, resumen.getFecha());
        assertFalse(resumen.isYaRegistrada());
        assertEquals(new BigDecimal("74.50"), resumen.getMontoSugerido());
        assertEquals(23, resumen.getCantidadOperacionesSugeridas());
        assertNotNull(resumen.getBaseLegal());
    }

    @Test
    void testObtenerSugerencia_ConRegistroPrevio_RetornaDatosRegistrados() {
        when(tenantService.getCurrentBodegaId()).thenReturn(ID_BODEGA);
        LocalDate fecha = LocalDate.of(2026, 11, 3);

        BoletaConsolidada bc = BoletaConsolidada.builder()
                .idBoletaConsolidada(10L)
                .bodega(bodega)
                .fechaEmision(fecha)
                .montoTotal(new BigDecimal("75.00"))
                .cantidadOperaciones(24)
                .serieCorrelativo("001-000456")
                .tipoEmision("TALONARIO_FISICO")
                .observaciones("24 compras de golosinas y abarrotes")
                .usuarioRegistro("carlos")
                .build();

        when(boletaConsolidadaRepository.findByBodega_IdBodegaAndFechaEmision(ID_BODEGA, fecha))
                .thenReturn(Optional.of(bc));
        when(ventaRepository.sumVentasMenores(eq(ID_BODEGA), any(BigDecimal.class), any(OffsetDateTime.class), any(OffsetDateTime.class)))
                .thenReturn(new BigDecimal("74.50"));
        when(ventaRepository.countVentasMenores(eq(ID_BODEGA), any(BigDecimal.class), any(OffsetDateTime.class), any(OffsetDateTime.class)))
                .thenReturn(23L);

        ResumenVentasMenoresDTO resumen = boletaConsolidadaService.obtenerSugerencia(fecha);

        assertNotNull(resumen);
        assertTrue(resumen.isYaRegistrada());
        assertEquals(10L, resumen.getIdBoletaConsolidada());
        assertEquals("001-000456", resumen.getSerieCorrelativo());
        assertEquals(new BigDecimal("75.00"), resumen.getMontoRegistrado());
        assertEquals(24, resumen.getCantidadOperacionesRegistradas());
    }

    @Test
    void testRegistrarBoletaConsolidada_CreaNuevoRegistro() {
        when(tenantService.getCurrentBodegaId()).thenReturn(ID_BODEGA);
        when(bodegaRepository.findById(ID_BODEGA)).thenReturn(Optional.of(bodega));

        LocalDate fecha = LocalDate.of(2026, 11, 3);
        RegistrarBoletaConsolidadaDTO dto = RegistrarBoletaConsolidadaDTO.builder()
                .fecha(fecha)
                .montoTotal(new BigDecimal("82.30"))
                .cantidadOperaciones(28)
                .serieCorrelativo("B001-00000015")
                .tipoEmision("DIGITAL_CAJAYA")
                .observaciones("Ventas menores tarde y noche")
                .build();

        when(boletaConsolidadaRepository.findByBodega_IdBodegaAndFechaEmision(ID_BODEGA, fecha))
                .thenReturn(Optional.empty());

        when(boletaConsolidadaRepository.save(any(BoletaConsolidada.class))).thenAnswer(invocation -> {
            BoletaConsolidada saved = invocation.getArgument(0);
            saved.setIdBoletaConsolidada(100L);
            return saved;
        });

        BoletaConsolidadaDTO resultado = boletaConsolidadaService.registrarBoletaConsolidada(dto);

        assertNotNull(resultado);
        assertEquals(100L, resultado.getIdBoletaConsolidada());
        assertEquals("B001-00000015", resultado.getSerieCorrelativo());
        assertEquals(new BigDecimal("82.30"), resultado.getMontoTotal());
        assertEquals(28, resultado.getCantidadOperaciones());
        verify(boletaConsolidadaRepository, times(1)).save(any(BoletaConsolidada.class));
    }

    @Test
    void testListarHistorial_RetornaListaOrdenada() {
        when(tenantService.getCurrentBodegaId()).thenReturn(ID_BODEGA);

        BoletaConsolidada bc1 = BoletaConsolidada.builder()
                .idBoletaConsolidada(1L)
                .bodega(bodega)
                .fechaEmision(LocalDate.of(2026, 11, 3))
                .montoTotal(new BigDecimal("50.00"))
                .cantidadOperaciones(15)
                .serieCorrelativo("001-00001")
                .build();

        when(boletaConsolidadaRepository.findTop30ByBodega_IdBodegaOrderByFechaEmisionDesc(ID_BODEGA))
                .thenReturn(List.of(bc1));

        List<BoletaConsolidadaDTO> lista = boletaConsolidadaService.listarHistorial(30);

        assertNotNull(lista);
        assertEquals(1, lista.size());
        assertEquals("001-00001", lista.get(0).getSerieCorrelativo());
    }
}
