package com.bodega.backend.service;

import com.bodega.backend.dto.CrearSugerenciaSuperadminDTO;
import com.bodega.backend.dto.SugerenciaPrecioDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.entity.SugerenciaPrecioSuperadmin;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.SugerenciaPrecioRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SugerenciaPrecioServiceTest {

    @Mock
    private SugerenciaPrecioRepository sugerenciaPrecioRepository;

    @Mock
    private ProductoRepository productoRepository;

    @Mock
    private TenantService tenantService;

    @Mock
    private AnalyticsService analyticsService;

    @InjectMocks
    private SugerenciaPrecioService sugerenciaPrecioService;

    private Bodega bodega1;
    private Bodega bodega2;
    private Producto producto1;
    private Producto producto2;

    @BeforeEach
    void setUp() {
        bodega1 = new Bodega();
        bodega1.setIdBodega(1L);
        bodega1.setNombreComercial("Bodega Karliz");

        bodega2 = new Bodega();
        bodega2.setIdBodega(2L);
        bodega2.setNombreComercial("Bodega Central");

        producto1 = new Producto();
        producto1.setIdProducto(101L);
        producto1.setBodega(bodega1);
        producto1.setCodigoBarras("7750106001015");
        producto1.setNombre("Arroz Costeño Extra 1kg");
        producto1.setMarca("Costeño");
        producto1.setPrecioVenta(new BigDecimal("4.50"));
        producto1.setPrecioCosto(new BigDecimal("3.80"));
        producto1.setEstado(true);

        producto2 = new Producto();
        producto2.setIdProducto(202L);
        producto2.setBodega(bodega2);
        producto2.setCodigoBarras("7750106001015");
        producto2.setNombre("Arroz Costeño Extra 1kg");
        producto2.setMarca("Costeño");
        producto2.setPrecioVenta(new BigDecimal("4.20"));
        producto2.setPrecioCosto(new BigDecimal("3.70"));
        producto2.setEstado(true);

        var auth = new UsernamePasswordAuthenticationToken(
                "superadmin@cajaya.pe", "secret", List.of(new SimpleGrantedAuthority("ROLE_SUPERADMIN"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    @Test
    void testDifundirSugerencia_broadcastsToAllStoresWithProduct() {
        CrearSugerenciaSuperadminDTO dto = CrearSugerenciaSuperadminDTO.builder()
                .codigoBarras("7750106001015")
                .precioVentaSugerido(new BigDecimal("4.80"))
                .precioCostoSugerido(new BigDecimal("3.90"))
                .nombreSugerido("Arroz Costeño Extra 1kg Premium")
                .marcaSugerida("Costeño")
                .motivo("Alza de precios de fábrica sugerida")
                .build();

        when(productoRepository.findByCodigoBarrasAndEstadoTrue("7750106001015"))
                .thenReturn(List.of(producto1, producto2));
        when(sugerenciaPrecioRepository.findByBodega_IdBodegaAndCodigoBarrasAndEstado(any(), any(), eq("PENDIENTE")))
                .thenReturn(Optional.empty());
        when(sugerenciaPrecioRepository.save(any(SugerenciaPrecioSuperadmin.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        int notificadas = sugerenciaPrecioService.difundirSugerencia(dto);

        assertEquals(2, notificadas);
        verify(sugerenciaPrecioRepository, times(2)).save(any(SugerenciaPrecioSuperadmin.class));
    }

    @Test
    void testDifundirSugerencia_updatesExistingPendingSuggestion() {
        CrearSugerenciaSuperadminDTO dto = CrearSugerenciaSuperadminDTO.builder()
                .codigoBarras("7750106001015")
                .precioVentaSugerido(new BigDecimal("5.00"))
                .motivo("Nuevo ajuste de precio")
                .build();

        SugerenciaPrecioSuperadmin existente = SugerenciaPrecioSuperadmin.builder()
                .idSugerencia(10L)
                .bodega(bodega1)
                .producto(producto1)
                .codigoBarras("7750106001015")
                .precioVentaActual(new BigDecimal("4.50"))
                .precioVentaSugerido(new BigDecimal("4.80"))
                .estado("PENDIENTE")
                .build();

        when(productoRepository.findByCodigoBarrasAndEstadoTrue("7750106001015"))
                .thenReturn(List.of(producto1));
        when(sugerenciaPrecioRepository.findByBodega_IdBodegaAndCodigoBarrasAndEstado(1L, "7750106001015", "PENDIENTE"))
                .thenReturn(Optional.of(existente));
        when(sugerenciaPrecioRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        int notificadas = sugerenciaPrecioService.difundirSugerencia(dto);

        assertEquals(1, notificadas);
        assertEquals(new BigDecimal("5.00"), existente.getPrecioVentaSugerido());
        assertEquals("Nuevo ajuste de precio", existente.getMotivo());
    }

    @Test
    void testContarBodegasConProducto() {
        when(sugerenciaPrecioRepository.countBodegasConProducto("7750106001015")).thenReturn(5L);

        long count = sugerenciaPrecioService.contarBodegasConProducto("7750106001015");

        assertEquals(5L, count);
    }

    @Test
    void testAceptarSugerencia_appliesUpdatesToProductAndMarksAccepted() {
        SugerenciaPrecioSuperadmin sug = SugerenciaPrecioSuperadmin.builder()
                .idSugerencia(99L)
                .bodega(bodega1)
                .producto(producto1)
                .codigoBarras("7750106001015")
                .nombreActual("Arroz Costeño Extra 1kg")
                .nombreSugerido("Arroz Costeño Grano Largo 1kg")
                .marcaActual("Costeño")
                .marcaSugerida("Costeño Gourmet")
                .precioVentaActual(new BigDecimal("4.50"))
                .precioVentaSugerido(new BigDecimal("4.90"))
                .precioCostoActual(new BigDecimal("3.80"))
                .precioCostoSugerido(new BigDecimal("4.00"))
                .estado("PENDIENTE")
                .build();

        when(sugerenciaPrecioRepository.findById(99L)).thenReturn(Optional.of(sug));
        when(sugerenciaPrecioRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SugerenciaPrecioDTO resultado = sugerenciaPrecioService.aceptarSugerencia(99L);

        assertEquals("ACEPTADA", resultado.getEstado());
        assertEquals(new BigDecimal("4.90"), producto1.getPrecioVenta());
        assertEquals(new BigDecimal("4.00"), producto1.getPrecioCosto());
        assertEquals("Arroz Costeño Grano Largo 1kg", producto1.getNombre());
        assertEquals("Costeño Gourmet", producto1.getMarca());
        verify(productoRepository, times(1)).save(producto1);
    }

    @Test
    void testRechazarSugerencia_doesNotModifyProduct() {
        SugerenciaPrecioSuperadmin sug = SugerenciaPrecioSuperadmin.builder()
                .idSugerencia(99L)
                .bodega(bodega1)
                .producto(producto1)
                .codigoBarras("7750106001015")
                .precioVentaActual(new BigDecimal("4.50"))
                .precioVentaSugerido(new BigDecimal("5.50"))
                .estado("PENDIENTE")
                .build();

        when(sugerenciaPrecioRepository.findById(99L)).thenReturn(Optional.of(sug));
        when(sugerenciaPrecioRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SugerenciaPrecioDTO resultado = sugerenciaPrecioService.rechazarSugerencia(99L);

        assertEquals("RECHAZADA", resultado.getEstado());
        assertEquals(new BigDecimal("4.50"), producto1.getPrecioVenta()); // Sin cambios
        verify(productoRepository, never()).save(any());
    }

    @Test
    void testAceptarSugerencia_throwsWhenNotPending() {
        SugerenciaPrecioSuperadmin sug = SugerenciaPrecioSuperadmin.builder()
                .idSugerencia(99L)
                .bodega(bodega1)
                .producto(producto1)
                .estado("ACEPTADA")
                .build();

        when(sugerenciaPrecioRepository.findById(99L)).thenReturn(Optional.of(sug));

        assertThrows(IllegalStateException.class, () -> sugerenciaPrecioService.aceptarSugerencia(99L));
    }

    @Test
    void testObtenerEstadisticas() {
        when(sugerenciaPrecioRepository.count()).thenReturn(10L);
        when(sugerenciaPrecioRepository.countByEstado("PENDIENTE")).thenReturn(3L);
        when(sugerenciaPrecioRepository.countByEstado("ACEPTADA")).thenReturn(5L);
        when(sugerenciaPrecioRepository.countByEstado("RECHAZADA")).thenReturn(2L);

        java.util.Map<String, Object> stats = sugerenciaPrecioService.obtenerEstadisticas();

        assertEquals(10L, stats.get("totalSugerencias"));
        assertEquals(3L, stats.get("totalPendientes"));
        assertEquals(5L, stats.get("totalAceptadas"));
        assertEquals(2L, stats.get("totalRechazadas"));
        // 5 / (5 + 2) * 100 = 71.4%
        assertEquals(71.4, (Double) stats.get("tasaAceptacion"), 0.1);
    }
}
