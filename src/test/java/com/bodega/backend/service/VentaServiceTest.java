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
}
