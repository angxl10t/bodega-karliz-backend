package com.bodega.backend.service;

import com.bodega.backend.dto.DashboardBiDTO;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.VentaDetalleRepository;
import com.bodega.backend.repository.VentaRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class AnalyticsServiceTest {

    @Mock
    private VentaRepository ventaRepository;

    @Mock
    private VentaDetalleRepository ventaDetalleRepository;

    @Mock
    private ProductoRepository productoRepository;

    @Mock
    private TenantService tenantService;

    @InjectMocks
    private AnalyticsService analyticsService;

    @BeforeEach
    void setUp() {
        lenient().when(tenantService.getCurrentBodegaId()).thenReturn(1L);
    }

    @Test
    void testObtenerDashboardBi_CalculosCorrectos() {
        // Mock de totales en BD
        when(ventaRepository.sumTotalVentasByPeriodo(eq(1L), any(OffsetDateTime.class)))
                .thenReturn(new BigDecimal("1000.00"));
        when(ventaRepository.countVentasByPeriodo(eq(1L), any(OffsetDateTime.class)))
                .thenReturn(20L);
        when(ventaDetalleRepository.sumTotalCostosByPeriodo(eq(1L), any(OffsetDateTime.class)))
                .thenReturn(new BigDecimal("700.00"));

        // Mock de productos estrella: [idProducto, nombre, codigo, categoria, imagenUrl, cant, ventas, costo]
        List<Object[]> rawEstrellas = new ArrayList<>();
        rawEstrellas.add(new Object[]{
                10L,
                "Arroz Costeño 1kg",
                "P010",
                "Abarrotes",
                null,
                new BigDecimal("50.000"),
                new BigDecimal("250.00"),
                new BigDecimal("175.00")
        });
        when(ventaDetalleRepository.findTopEstrellasByPeriodo(eq(1L), any(OffsetDateTime.class), any(Pageable.class)))
                .thenReturn(rawEstrellas);

        // Mock de mapa horario: [hora, cantidadVentas, totalSoles]
        List<Object[]> rawHoras = new ArrayList<>();
        rawHoras.add(new Object[]{14, 8L, new BigDecimal("400.00")});
        when(ventaRepository.findDistribucionHorariaNative(eq(1L), any(OffsetDateTime.class)))
                .thenReturn(rawHoras);

        // Mock de productos hueso: [idProducto, nombre, codigo, categoria, imagenUrl, stockActual, precioCosto, capitalInmovilizado, fechaVencimiento]
        List<Object[]> rawHuesos = new ArrayList<>();
        rawHuesos.add(new Object[]{99L, "Enlatado Antiguo", "P099", "Abarrotes", null, new BigDecimal("12.000"), new BigDecimal("3.50"), new BigDecimal("42.00"), null});
        when(productoRepository.findProductosHuesoByPeriodo(eq(1L), any(OffsetDateTime.class), any(Pageable.class)))
                .thenReturn(rawHuesos);

        List<Object[]> rawCapital = new ArrayList<>();
        rawCapital.add(new Object[]{new BigDecimal("42.00"), 1L});
        when(productoRepository.calculateCapitalInmovilizado(eq(1L), any(OffsetDateTime.class)))
                .thenReturn(rawCapital);

        DashboardBiDTO dto = analyticsService.obtenerDashboardBi(30);

        assertNotNull(dto);
        assertEquals(new BigDecimal("1000.00"), dto.getTotalVentas());
        assertEquals(new BigDecimal("700.00"), dto.getTotalCostos());
        assertEquals(new BigDecimal("300.00"), dto.getMargenBrutoSoles());
        assertEquals(new BigDecimal("30.0"), dto.getPorcentajeMargenBruto());
        assertEquals(new BigDecimal("50.00"), dto.getTicketPromedioPeriodo());
        assertEquals(new BigDecimal("42.00"), dto.getTotalCapitalInmovilizado());

        assertFalse(dto.getProductosEstrella().isEmpty());
        assertEquals("Arroz Costeño 1kg", dto.getProductosEstrella().get(0).getNombre());

        assertFalse(dto.getProductosHueso().isEmpty());
        assertEquals("Enlatado Antiguo", dto.getProductosHueso().get(0).getNombre());

        assertEquals(24, dto.getDistribucionHoraria().size());
        assertEquals(8, dto.getDistribucionHoraria().get(14).getCantidadTickets());
    }

    @Test
    void testCache_EvitaConsultasRepetidas() {
        when(ventaRepository.sumTotalVentasByPeriodo(eq(1L), any(OffsetDateTime.class)))
                .thenReturn(new BigDecimal("500.00"));
        when(ventaRepository.countVentasByPeriodo(eq(1L), any(OffsetDateTime.class)))
                .thenReturn(10L);
        when(ventaDetalleRepository.sumTotalCostosByPeriodo(eq(1L), any(OffsetDateTime.class)))
                .thenReturn(new BigDecimal("350.00"));
        when(ventaDetalleRepository.findTopEstrellasByPeriodo(eq(1L), any(OffsetDateTime.class), any(Pageable.class)))
                .thenReturn(Collections.emptyList());
        when(ventaRepository.findDistribucionHorariaNative(eq(1L), any(OffsetDateTime.class)))
                .thenReturn(Collections.emptyList());
        when(productoRepository.findProductosHuesoByPeriodo(eq(1L), any(OffsetDateTime.class), any(Pageable.class)))
                .thenReturn(Collections.emptyList());
        when(productoRepository.calculateCapitalInmovilizado(eq(1L), any(OffsetDateTime.class)))
                .thenReturn(Collections.emptyList());

        // Primera llamada: llena el caché
        DashboardBiDTO primerLlamado = analyticsService.obtenerDashboardBi(30);
        assertNotNull(primerLlamado);

        // Segunda llamada inmediata: debe servirse del caché sin invocar a los repositorios
        DashboardBiDTO segundoLlamado = analyticsService.obtenerDashboardBi(30);
        assertSame(primerLlamado, segundoLlamado);

        // Verificar que countVentasByPeriodo se ejecutó solo 3 veces (para periodo, hoy y semana) en la primera llamada
        verify(ventaRepository, times(3)).countVentasByPeriodo(eq(1L), any(OffsetDateTime.class));

        // Invalidar caché
        analyticsService.invalidateCache(1L);

        // Tercera llamada: vuelve a consultar la BD
        DashboardBiDTO tercerLlamado = analyticsService.obtenerDashboardBi(30);
        assertNotNull(tercerLlamado);
        verify(ventaRepository, times(6)).countVentasByPeriodo(eq(1L), any(OffsetDateTime.class));
    }
}
