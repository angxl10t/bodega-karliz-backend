package com.bodega.backend.service;

import com.bodega.backend.entity.MovimientoInventario;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.entity.Venta;
import com.bodega.backend.entity.VentaDetalle;
import com.bodega.backend.repository.MovimientoInventarioRepository;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.VentaDetalleRepository;
import com.bodega.backend.repository.VentaRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;
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
public class VentaServiceTest {

    @Mock
    private VentaRepository ventaRepository;

    @Mock
    private VentaDetalleRepository ventaDetalleRepository;

    @Mock
    private ProductoRepository productoRepository;

    @Mock
    private MovimientoInventarioRepository movimientoInventarioRepository;

    @Mock
    private TenantService tenantService;

    @Mock
    private com.bodega.backend.repository.BodegaRepository bodegaRepository;

    @Mock
    private SunatRestEmissionService sunatRestEmissionService;

    @InjectMocks
    private VentaService ventaService;

    @BeforeEach
    void setUp() {
        // Simular usuario ADMIN autenticado por defecto
        var auth = new UsernamePasswordAuthenticationToken(
                "admin", "password", List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
        SecurityContextHolder.getContext().setAuthentication(auth);
        lenient().when(tenantService.getCurrentBodegaId()).thenReturn(1L);
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void testAnularVenta_NoAdmin_LanzaAccessDeniedException() {
        // Simular cajero no admin
        var authCajero = new UsernamePasswordAuthenticationToken(
                "cajero1", "password", List.of(new SimpleGrantedAuthority("ROLE_CAJERO")));
        SecurityContextHolder.getContext().setAuthentication(authCajero);

        assertThrows(AccessDeniedException.class, () -> ventaService.anularVenta(1L, "Error de tipeo"));
        verify(ventaRepository, never()).findByIdForUpdateAndBodega(any(), any());
    }

    @Test
    void testAnularVenta_YaAnulada_LanzaExcepcionIdempotencia() {
        Venta venta = new Venta();
        venta.setIdVenta(1L);
        venta.setEstado("ANULADA");

        when(ventaRepository.findByIdForUpdateAndBodega(1L, 1L)).thenReturn(Optional.of(venta));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> ventaService.anularVenta(1L, "Intento doble"));
        assertTrue(ex.getMessage().contains("ya se encuentra anulada"));
        verify(productoRepository, never()).findByIdForUpdateAndBodega(any(), any());
    }

    @Test
    void testAnularVenta_Exito_RestauraStockRegistraKardex() {
        Venta venta = new Venta();
        venta.setIdVenta(1L);
        venta.setEstado("COMPLETADA");

        Producto prod = new Producto();
        prod.setIdProducto(10L);
        prod.setNombre("Inca Kola 500ml");
        prod.setStockActual(new BigDecimal("5.000"));

        VentaDetalle det = new VentaDetalle();
        det.setIdDetalleVenta(100L);
        det.setVenta(venta);
        det.setProducto(prod);
        det.setCantidad(new BigDecimal("3.000"));

        when(ventaRepository.findByIdForUpdateAndBodega(1L, 1L)).thenReturn(Optional.of(venta));
        when(ventaDetalleRepository.findByVenta(venta)).thenReturn(List.of(det));
        when(productoRepository.findByIdForUpdateAndBodega(10L, 1L)).thenReturn(Optional.of(prod));

        ventaService.anularVenta(1L, "Cliente canceló pedido");

        // 1. Verifica que el stock se restauró de 5 a 8
        assertEquals(new BigDecimal("8.000"), prod.getStockActual());
        verify(productoRepository, times(1)).save(prod);

        // 2. Verifica que se registró movimiento ENTRADA en Kardex
        verify(movimientoInventarioRepository, times(1)).save(any(MovimientoInventario.class));

        // 3. Verifica que la venta quedó marcada como ANULADA
        assertEquals("ANULADA", venta.getEstado());
        assertEquals("admin", venta.getUsuarioAnulacion());
        assertNotNull(venta.getFechaAnulacion());
        verify(ventaRepository, times(1)).save(venta);
    }

    @Test
    void testRegistrarVenta_Idempotencia_RetornaVentaExistenteSinDobleCobro() {
        String key = "idemp-pos-uuid-9999";
        com.bodega.backend.dto.VentaDTO dto = new com.bodega.backend.dto.VentaDTO();
        dto.setIdempotencyKey(key);

        Venta ventaExistente = new Venta();
        ventaExistente.setIdVenta(55L);
        ventaExistente.setTotal(new BigDecimal("25.00"));
        ventaExistente.setEstado("COMPLETADA");
        ventaExistente.setIdempotencyKey(key);

        when(ventaRepository.findByBodega_IdBodegaAndIdempotencyKey(1L, key))
                .thenReturn(Optional.of(ventaExistente));
        when(ventaDetalleRepository.findByVenta(ventaExistente))
                .thenReturn(List.of());

        com.bodega.backend.dto.VentaDTO resultado = ventaService.registrarVenta(dto);

        assertNotNull(resultado);
        assertEquals(55L, resultado.getIdVenta());
        assertEquals(new BigDecimal("25.00"), resultado.getTotal());
        assertEquals(key, resultado.getIdempotencyKey());

        // Blindaje contra doble cobro: No busca productos ni descuenta stock
        verify(productoRepository, never()).findByIdForUpdateAndBodega(any(), any());
        verify(ventaRepository, never()).save(any(Venta.class));
    }

    @Test
    void testRegistrarVenta_FacturacionSunat_IncrementaCorrelativoConBloqueoPesimista() {
        com.bodega.backend.entity.Bodega bodega = new com.bodega.backend.entity.Bodega();
        bodega.setIdBodega(1L);
        bodega.setFacturacionSunatActiva(true);
        bodega.setSerieBoleta("B001");
        bodega.setUltimoCorrelativoBoleta(15L);

        when(tenantService.getCurrentBodega()).thenReturn(bodega);
        when(bodegaRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(bodega));

        Producto prod = new Producto();
        prod.setIdProducto(10L);
        prod.setNombre("Galletas Soda");
        prod.setPrecioVenta(new BigDecimal("1.50"));
        prod.setStockActual(new BigDecimal("50.000"));
        prod.setEstado(true);

        when(productoRepository.findByIdForUpdateAndBodega(10L, 1L)).thenReturn(Optional.of(prod));
        when(ventaRepository.save(any(Venta.class))).thenAnswer(invocation -> {
            Venta v = invocation.getArgument(0);
            v.setIdVenta(88L);
            return v;
        });

        com.bodega.backend.dto.VentaDTO dto = new com.bodega.backend.dto.VentaDTO();
        dto.setMetodoPago("Efectivo");
        com.bodega.backend.dto.VentaDetalleDTO item = new com.bodega.backend.dto.VentaDetalleDTO();
        item.setIdProducto(10L);
        item.setCantidad(new BigDecimal("2.000"));
        dto.setDetalles(List.of(item));

        com.bodega.backend.dto.VentaDTO ventaGenerada = ventaService.registrarVenta(dto);

        assertNotNull(ventaGenerada);
        assertEquals("BOLETA_ELECTRONICA", ventaGenerada.getTipoComprobante());
        assertEquals("B001-00000016", ventaGenerada.getSerieCorrelativo());
        assertEquals(16L, bodega.getUltimoCorrelativoBoleta());

        // Verifica que se ejecutó con bloqueo pesimista en la Bodega
        verify(bodegaRepository, times(1)).findByIdForUpdate(1L);
        verify(bodegaRepository, times(1)).save(bodega);
    }
}
