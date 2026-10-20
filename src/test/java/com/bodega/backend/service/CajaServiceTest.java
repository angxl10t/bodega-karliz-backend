package com.bodega.backend.service;

import com.bodega.backend.dto.CierreCajaDTO;
import com.bodega.backend.dto.EgresoCajaDTO;
import com.bodega.backend.dto.FondoCajaDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.EgresoCaja;
import com.bodega.backend.entity.FondoCaja;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.EgresoCajaRepository;
import com.bodega.backend.repository.FondoCajaRepository;
import org.junit.jupiter.api.AfterEach;
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
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class CajaServiceTest {

    @Mock
    private EgresoCajaRepository egresoCajaRepository;

    @Mock
    private FondoCajaRepository fondoCajaRepository;

    @Mock
    private BodegaRepository bodegaRepository;

    @Mock
    private TenantService tenantService;

    @Mock
    private VentaService ventaService;

    @InjectMocks
    private CajaService cajaService;

    private Bodega bodega;

    @BeforeEach
    void setUp() {
        bodega = new Bodega();
        bodega.setIdBodega(1L);
        bodega.setNombreComercial("Bodega Test");

        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                "cajero1", "password", List.of(new SimpleGrantedAuthority("ROLE_CAJERO")));
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void testRegistrarEgresoExitoso() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodega));

        EgresoCajaDTO dto = new EgresoCajaDTO();
        dto.setMonto(new BigDecimal("15.50"));
        dto.setMotivo("Compra de bolsas plásticas");
        dto.setCategoriaGasto("BOLSAS");

        EgresoCaja guardado = new EgresoCaja();
        guardado.setIdEgreso(10L);
        guardado.setMonto(new BigDecimal("15.50"));
        guardado.setMotivo("Compra de bolsas plásticas");
        guardado.setCategoriaGasto("BOLSAS");
        guardado.setUsuarioRegistro("cajero1");
        guardado.setEstado(true);
        guardado.setFechaEgreso(OffsetDateTime.now());

        when(egresoCajaRepository.save(any(EgresoCaja.class))).thenReturn(guardado);

        EgresoCajaDTO res = cajaService.registrarEgreso(dto);
        assertNotNull(res);
        assertEquals(10L, res.getIdEgreso());
        assertEquals(new BigDecimal("15.50"), res.getMonto());
        assertEquals("BOLSAS", res.getCategoriaGasto());
        assertEquals("cajero1", res.getUsuarioRegistro());
    }

    @Test
    void testRegistrarEgresoMontoInvalidoLanzaExcepcion() {
        EgresoCajaDTO dto = new EgresoCajaDTO();
        dto.setMonto(BigDecimal.ZERO);
        dto.setMotivo("Gasto inválido");

        assertThrows(IllegalArgumentException.class, () -> cajaService.registrarEgreso(dto));
    }

    @Test
    void testAnularEgresoExitoso() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);

        EgresoCaja egreso = new EgresoCaja();
        egreso.setIdEgreso(5L);
        egreso.setEstado(true);

        when(egresoCajaRepository.findByIdEgresoAndBodega_IdBodega(5L, 1L)).thenReturn(Optional.of(egreso));

        cajaService.anularEgreso(5L, "Error en monto");

        assertFalse(egreso.getEstado());
        assertEquals("cajero1", egreso.getUsuarioAnulacion());
        assertEquals("Error en monto", egreso.getMotivoAnulacion());
        assertNotNull(egreso.getFechaAnulacion());
        verify(egresoCajaRepository).save(egreso);
    }

    @Test
    void testAnularEgresoYaAnuladoLanzaExcepcion() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);

        EgresoCaja egreso = new EgresoCaja();
        egreso.setIdEgreso(5L);
        egreso.setEstado(false);

        when(egresoCajaRepository.findByIdEgresoAndBodega_IdBodega(5L, 1L)).thenReturn(Optional.of(egreso));

        assertThrows(IllegalStateException.class, () -> cajaService.anularEgreso(5L, "Reintento"));
    }

    @Test
    void testRegistrarFondoInicial() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodega));

        LocalDate hoy = LocalDate.now();
        when(fondoCajaRepository.findByBodega_IdBodegaAndFecha(1L, hoy)).thenReturn(Optional.empty());

        FondoCajaDTO dto = new FondoCajaDTO();
        dto.setMontoInicial(new BigDecimal("50.00"));
        dto.setFecha(hoy);

        FondoCaja guardado = new FondoCaja();
        guardado.setIdFondoCaja(1L);
        guardado.setMontoInicial(new BigDecimal("50.00"));
        guardado.setFecha(hoy);
        guardado.setUsuarioRegistro("cajero1");

        when(fondoCajaRepository.save(any(FondoCaja.class))).thenReturn(guardado);

        FondoCajaDTO res = cajaService.registrarFondoInicial(dto);
        assertNotNull(res);
        assertEquals(new BigDecimal("50.00"), res.getMontoInicial());
        assertEquals(hoy, res.getFecha());
    }

    @Test
    void testObtenerArqueoCompletoCalculaDiferenciasCorrectamente() {
        LocalDate hoy = LocalDate.now();
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);

        CierreCajaDTO cierreBase = new CierreCajaDTO();
        cierreBase.setTotalVentas(new BigDecimal("300.00"));
        cierreBase.setTotalEfectivo(new BigDecimal("200.00"));
        cierreBase.setTotalYape(new BigDecimal("100.00"));
        cierreBase.setCantidadVentas(5);

        when(ventaService.obtenerCierreCajaPorFecha(hoy)).thenReturn(cierreBase);

        FondoCaja fondo = new FondoCaja();
        fondo.setMontoInicial(new BigDecimal("50.00"));
        fondo.setFecha(hoy);
        when(fondoCajaRepository.findByBodega_IdBodegaAndFecha(1L, hoy)).thenReturn(Optional.of(fondo));

        EgresoCaja egreso = new EgresoCaja();
        egreso.setIdEgreso(1L);
        egreso.setMonto(new BigDecimal("20.00"));
        egreso.setMotivo("Bolsas");
        egreso.setCategoriaGasto("VARIOS");

        when(egresoCajaRepository.findByBodega_IdBodegaAndFechaEgresoBetweenAndEstadoTrueOrderByFechaEgresoDesc(
                eq(1L), any(OffsetDateTime.class), any(OffsetDateTime.class)))
                .thenReturn(List.of(egreso));

        CierreCajaDTO res = cajaService.obtenerArqueoCompleto(hoy);
        assertNotNull(res);
        assertEquals(new BigDecimal("50.00"), res.getFondoInicial());
        assertEquals(new BigDecimal("20.00"), res.getTotalEgresos());
        // Esperado = Fondo (50) + Efectivo Ventas (200) - Egresos (20) = 230.00
        assertEquals(new BigDecimal("230.00"), res.getTotalEfectivoEsperado());
        assertEquals(1, res.getEgresos().size());
    }
}
