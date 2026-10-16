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
        verify(userSecurityCacheService, times(1)).evictAll();
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
}
