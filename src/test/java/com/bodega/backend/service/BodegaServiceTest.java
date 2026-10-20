package com.bodega.backend.service;

import com.bodega.backend.dto.BodegaDTO;
import com.bodega.backend.dto.ConfiguracionSunatDTO;
import com.bodega.backend.dto.PagoYapeDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.security.UserSecurityCacheService;
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
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class BodegaServiceTest {

    @Mock
    private BodegaRepository bodegaRepository;

    @Mock
    private TenantService tenantService;

    @Mock
    private UserSecurityCacheService userSecurityCacheService;

    @Mock
    private com.bodega.backend.repository.PagoSuscripcionRepository pagoSuscripcionRepository;

    @Mock
    private com.bodega.backend.repository.UsuarioRepository usuarioRepository;

    @Mock
    private com.bodega.backend.repository.VentaRepository ventaRepository;

    @Mock
    private com.bodega.backend.repository.ProductoRepository productoRepository;

    @Mock
    private com.bodega.backend.repository.CompraRepository compraRepository;

    @Mock
    private com.bodega.backend.repository.MovimientoInventarioRepository movimientoInventarioRepository;

    @Mock
    private com.bodega.backend.repository.CategoriaRepository categoriaRepository;

    @Mock
    private org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;

    @InjectMocks
    private BodegaService bodegaService;

    private Bodega bodega;

    @BeforeEach
    void setUp() {
        bodega = new Bodega();
        bodega.setIdBodega(1L);
        bodega.setNombreComercial("Bodega KARLIZ");
        bodega.setPlan("BASICO");
        bodega.setFacturacionSunatActiva(false);
        bodega.setFechaVencimientoPlan(OffsetDateTime.now().plusDays(5));

        lenient().when(tenantService.getCurrentBodega()).thenReturn(bodega);
        lenient().when(bodegaRepository.save(any(Bodega.class))).thenAnswer(inv -> inv.getArgument(0));
        lenient().when(pagoSuscripcionRepository.existsByBilleteraIgnoreCaseAndCodigoOperacion(anyString(), anyString())).thenReturn(false);

        var auth = new UsernamePasswordAuthenticationToken(
                "admin", "password", List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void testRegistrarPagoYape_PlanBodega_Extiende30DiasExitosamente() {
        PagoYapeDTO dto = new PagoYapeDTO();
        dto.setCodigoOperacion("849201");
        dto.setPlan("BASICO");
        dto.setMonto(new BigDecimal("50.00"));
        dto.setBilletera("YAPE");

        OffsetDateTime vencimientoAnterior = bodega.getFechaVencimientoPlan();
        BodegaDTO resultado = bodegaService.registrarPagoYape(dto);

        assertNotNull(resultado);
        assertEquals("BASICO", resultado.getPlan());
        assertTrue(resultado.getFechaVencimientoPlan().isAfter(vencimientoAnterior.plusDays(29)));
        verify(bodegaRepository, times(1)).save(bodega);
        verify(pagoSuscripcionRepository, times(1)).save(any(com.bodega.backend.entity.PagoSuscripcion.class));
        verify(userSecurityCacheService, times(1)).evictAll();
    }

    @Test
    void testRegistrarPagoYape_VoucherDuplicado_LanzaExcepcionAntiFraude() {
        PagoYapeDTO dto = new PagoYapeDTO();
        dto.setCodigoOperacion("849201");
        dto.setPlan("BASICO");
        dto.setMonto(new BigDecimal("50.00"));
        dto.setBilletera("YAPE");

        when(pagoSuscripcionRepository.existsByBilleteraIgnoreCaseAndCodigoOperacion("YAPE", "849201")).thenReturn(true);

        RuntimeException ex = assertThrows(RuntimeException.class, () -> bodegaService.registrarPagoYape(dto));
        assertTrue(ex.getMessage().contains("ya fue registrado y procesado previamente"));
        verify(bodegaRepository, never()).save(any());
        verify(pagoSuscripcionRepository, never()).save(any());
    }

    @Test
    void testRegistrarPagoYape_MontoInsuficiente_LanzaExcepcion() {
        PagoYapeDTO dto = new PagoYapeDTO();
        dto.setCodigoOperacion("123456");
        dto.setPlan("PRO");
        dto.setMonto(new BigDecimal("30.00")); // Tarifa oficial PRO es S/ 100
        dto.setBilletera("YAPE");

        RuntimeException ex = assertThrows(RuntimeException.class, () -> bodegaService.registrarPagoYape(dto));
        assertTrue(ex.getMessage().contains("es inferior a la tarifa oficial"));
        verify(bodegaRepository, never()).save(any());
    }

    @Test
    void testActualizarConfiguracionSunat_ComoAdmin_ActivaModuloExitosamente() {
        ConfiguracionSunatDTO dto = new ConfiguracionSunatDTO();
        dto.setFacturacionSunatActiva(true);
        dto.setSunatProveedor("SUNAT_DIRECTO_GRATUITO");
        dto.setSunatRucEmisor("20123456789");
        dto.setSunatUsuarioSol("MODDATOS");
        dto.setSerieBoleta("B001");
        dto.setSerieFactura("F001");

        BodegaDTO resultado = bodegaService.actualizarConfiguracionSunat(dto);

        assertNotNull(resultado);
        assertTrue(resultado.getFacturacionSunatActiva());
        assertEquals("20123456789", resultado.getSunatRucEmisor());
        assertEquals("B001", resultado.getSerieBoleta());
        verify(bodegaRepository, times(1)).save(bodega);
        verify(userSecurityCacheService, times(1)).evictAll();
    }

    @Test
    void testActualizarConfiguracionSunat_ComoCajero_DeniegaAccesoEstrictamente() {
        // Simular sesión de Cajero
        var authCajero = new UsernamePasswordAuthenticationToken(
                "cajero1", "password", List.of(new SimpleGrantedAuthority("ROLE_CAJERO")));
        SecurityContextHolder.getContext().setAuthentication(authCajero);

        ConfiguracionSunatDTO dto = new ConfiguracionSunatDTO();
        dto.setFacturacionSunatActiva(false); // Intento de desactivación por cajero

        RuntimeException ex = assertThrows(RuntimeException.class, () -> bodegaService.actualizarConfiguracionSunat(dto));
        assertTrue(ex.getMessage().contains("Solo el Administrador de la bodega puede activar"));
        verify(bodegaRepository, never()).save(any());
    }

    @Test
    void testActualizarConfiguracionSunat_SerieBoletaInvalida_LanzaExcepcion() {
        ConfiguracionSunatDTO dto = new ConfiguracionSunatDTO();
        dto.setSerieBoleta("INVALIDA"); // Serie no cumple formato ^B[A-Z0-9]{3}$

        RuntimeException ex = assertThrows(RuntimeException.class, () -> bodegaService.actualizarConfiguracionSunat(dto));
        assertTrue(ex.getMessage().contains("La serie de boleta debe tener 4 caracteres"));
        verify(bodegaRepository, never()).save(any());
    }

    @Test
    void testActualizarConfiguracionSunat_SerieFacturaInvalida_LanzaExcepcion() {
        ConfiguracionSunatDTO dto = new ConfiguracionSunatDTO();
        dto.setSerieFactura("123"); // Serie no cumple formato ^F[A-Z0-9]{3}$

        RuntimeException ex = assertThrows(RuntimeException.class, () -> bodegaService.actualizarConfiguracionSunat(dto));
        assertTrue(ex.getMessage().contains("La serie de factura debe tener 4 caracteres"));
        verify(bodegaRepository, never()).save(any());
    }

    @Test
    void testObtenerPorId_MismaBodega_Exitoso() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodega));

        BodegaDTO res = bodegaService.obtenerPorId(1L);

        assertNotNull(res);
        assertEquals("Bodega KARLIZ", res.getNombreComercial());
    }

    @Test
    void testObtenerPorId_OtraBodega_ComoAdmin_LanzaAccessDeniedException() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);

        assertThrows(org.springframework.security.access.AccessDeniedException.class, 
                () -> bodegaService.obtenerPorId(99L));
        verify(bodegaRepository, never()).findById(99L);
    }

    @Test
    void testObtenerPorId_OtraBodega_ComoSuperAdmin_PermiteAcceso() {
        var authSuper = new UsernamePasswordAuthenticationToken(
                "admin", "password", List.of(new SimpleGrantedAuthority("ROLE_SUPERADMIN")));
        SecurityContextHolder.getContext().setAuthentication(authSuper);

        Bodega otraBodega = new Bodega();
        otraBodega.setIdBodega(99L);
        otraBodega.setNombreComercial("Otra Tienda");
        when(bodegaRepository.findById(99L)).thenReturn(Optional.of(otraBodega));

        BodegaDTO res = bodegaService.obtenerPorId(99L);

        assertNotNull(res);
        assertEquals(99L, res.getIdBodega());
        assertEquals("Otra Tienda", res.getNombreComercial());
    }

    @Test
    void testCambiarEstadoBodega() {
        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodega));
        when(bodegaRepository.save(any(Bodega.class))).thenReturn(bodega);

        BodegaDTO result = bodegaService.cambiarEstadoBodega(1L, false);

        assertNotNull(result);
        assertFalse(bodega.getEstado());
        verify(userSecurityCacheService).evictAll();
    }

    @Test
    void testCambiarPlanBodega() {
        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodega));
        when(bodegaRepository.save(any(Bodega.class))).thenReturn(bodega);

        BodegaDTO result = bodegaService.cambiarPlanBodega(1L, "PRO", 60);

        assertNotNull(result);
        assertEquals("PRO", bodega.getPlan());
        assertNotNull(bodega.getFechaVencimientoPlan());
        verify(userSecurityCacheService).evictAll();
    }

    @Test
    void testObtenerMetricasSistema() {
        when(bodegaRepository.count()).thenReturn(1L);
        when(bodegaRepository.countByEstadoTrue()).thenReturn(1L);
        when(bodegaRepository.countByPlanIgnoreCase("PRO")).thenReturn(1L);
        when(usuarioRepository.count()).thenReturn(5L);
        when(ventaRepository.count()).thenReturn(120L);
        when(pagoSuscripcionRepository.count()).thenReturn(0L);
        when(pagoSuscripcionRepository.sumarTotalRecaudado()).thenReturn(java.math.BigDecimal.ZERO);

        java.util.Map<String, Object> metricas = bodegaService.obtenerMetricasSistema();

        assertNotNull(metricas);
        assertEquals(1L, metricas.get("totalBodegas"));
        assertEquals(1L, metricas.get("bodegasActivas"));
        assertEquals(5L, metricas.get("totalUsuarios"));
        assertEquals(120L, metricas.get("totalVentas"));
    }

    @Test
    void testProvisionarBodega() {
        com.bodega.backend.dto.ProvisionarBodegaDTO dto = new com.bodega.backend.dto.ProvisionarBodegaDTO();
        dto.setNombreComercial("Minimarket San Jorge");
        dto.setAdminUsername("admin_sanjorge");
        dto.setAdminPassword("secret123");
        dto.setPlan("PRO");
        dto.setDiasVigencia(60);

        when(usuarioRepository.existsByUsernameIgnoreCase("admin_sanjorge")).thenReturn(false);
        when(passwordEncoder.encode("secret123")).thenReturn("encoded_secret");
        when(bodegaRepository.save(any(Bodega.class))).thenAnswer(inv -> {
            Bodega b = inv.getArgument(0);
            b.setIdBodega(15L);
            return b;
        });

        BodegaDTO result = bodegaService.provisionarBodega(dto);

        assertNotNull(result);
        assertEquals("Minimarket San Jorge", result.getNombreComercial());
        assertEquals("PRO", result.getPlan());
        verify(usuarioRepository).save(any(com.bodega.backend.entity.Usuario.class));
        verify(userSecurityCacheService).evictAll();
    }

    @Test
    void testCambiarEstadoPago() {
        com.bodega.backend.entity.PagoSuscripcion pago = new com.bodega.backend.entity.PagoSuscripcion();
        pago.setIdPago(50L);
        pago.setEstado("PENDIENTE");
        pago.setCodigoOperacion("YP-991122");
        pago.setBilletera("YAPE");
        pago.setPlan("PRO");
        pago.setMonto(new BigDecimal("29.90"));

        when(pagoSuscripcionRepository.findById(50L)).thenReturn(Optional.of(pago));
        when(pagoSuscripcionRepository.save(any(com.bodega.backend.entity.PagoSuscripcion.class))).thenAnswer(inv -> inv.getArgument(0));

        com.bodega.backend.dto.PagoSuscripcionDTO result = bodegaService.cambiarEstadoPago(50L, "CONFIRMADO");

        assertNotNull(result);
        assertEquals("CONFIRMADO", result.getEstado());
        assertEquals("YP-991122", result.getCodigoOperacion());
    }

    @Test
    void testAnuncioGlobal() {
        assertTrue(bodegaService.obtenerAnuncioGlobal().isEmpty());

        java.util.Map<String, Object> req = java.util.Map.of("mensaje", "Mantenimiento domingo 2am", "tipo", "INFO");
        java.util.Map<String, Object> publicado = bodegaService.publicarAnuncioGlobal(req);

        assertNotNull(publicado);
        assertEquals("Mantenimiento domingo 2am", publicado.get("mensaje"));
        assertEquals(true, publicado.get("activo"));

        java.util.Map<String, Object> obtenido = bodegaService.obtenerAnuncioGlobal();
        assertFalse(obtenido.isEmpty());
        assertEquals("Mantenimiento domingo 2am", obtenido.get("mensaje"));

        bodegaService.eliminarAnuncioGlobal();
        assertTrue(bodegaService.obtenerAnuncioGlobal().isEmpty());
    }
}
