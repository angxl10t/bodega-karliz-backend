package com.bodega.backend.service;

import com.bodega.backend.dto.CompraDTO;
import com.bodega.backend.dto.CompraDetalleDTO;
import com.bodega.backend.entity.*;
import com.bodega.backend.repository.*;
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
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class CompraServiceTest {

    @Mock
    private CompraRepository compraRepository;

    @Mock
    private CompraDetalleRepository compraDetalleRepository;

    @Mock
    private ProveedorRepository proveedorRepository;

    @Mock
    private ProductoRepository productoRepository;

    @Mock
    private MovimientoInventarioRepository movimientoInventarioRepository;

    @Mock
    private TenantService tenantService;

    @InjectMocks
    private CompraService compraService;

    @BeforeEach
    void setUp() {
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
    void testRegistrarCompra_ProveedorNoEncontrado_LanzaExcepcion() {
        CompraDTO dto = new CompraDTO();
        dto.setIdProveedor(99L);
        dto.setDetalles(List.of());

        when(proveedorRepository.findByIdProveedorAndBodega_IdBodega(99L, 1L))
                .thenReturn(Optional.empty());

        RuntimeException ex = assertThrows(RuntimeException.class, () -> compraService.registrarCompra(dto));
        assertTrue(ex.getMessage().contains("Proveedor no encontrado en esta bodega"));
        verify(compraRepository, never()).save(any());
    }

    @Test
    void testRegistrarCompra_ProveedorInactivo_LanzaExcepcion() {
        Proveedor prov = new Proveedor();
        prov.setIdProveedor(5L);
        prov.setRazonSocial("Distribuidora Inactiva");
        prov.setEstado(false);

        CompraDTO dto = new CompraDTO();
        dto.setIdProveedor(5L);

        when(proveedorRepository.findByIdProveedorAndBodega_IdBodega(5L, 1L))
                .thenReturn(Optional.of(prov));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> compraService.registrarCompra(dto));
        assertTrue(ex.getMessage().contains("No se puede registrar compra para el proveedor inactivo"));
        verify(compraRepository, never()).save(any());
    }

    @Test
    void testRegistrarCompra_ComprobanteDuplicado_LanzaExcepcion() {
        Proveedor prov = new Proveedor();
        prov.setIdProveedor(5L);
        prov.setRazonSocial("Alicorp S.A.A.");
        prov.setEstado(true);

        CompraDTO dto = new CompraDTO();
        dto.setIdProveedor(5L);
        dto.setComprobante("F001-000123");

        when(proveedorRepository.findByIdProveedorAndBodega_IdBodega(5L, 1L))
                .thenReturn(Optional.of(prov));
        when(compraRepository.existsByBodega_IdBodegaAndProveedor_IdProveedorAndComprobanteIgnoreCase(1L, 5L, "F001-000123"))
                .thenReturn(true);

        RuntimeException ex = assertThrows(RuntimeException.class, () -> compraService.registrarCompra(dto));
        assertTrue(ex.getMessage().contains("Ya existe una compra registrada con el comprobante"));
        verify(compraRepository, never()).save(any());
    }

    @Test
    void testRegistrarCompra_Exito_IncrementaStockYRegistraKardex() {
        Proveedor prov = new Proveedor();
        prov.setIdProveedor(10L);
        prov.setRazonSocial("Backus & Johnston");
        prov.setEstado(true);

        Bodega bodega = new Bodega();
        bodega.setIdBodega(1L);
        bodega.setNombreComercial("CajaYa POS");

        Producto prod = new Producto();
        prod.setIdProducto(20L);
        prod.setNombre("Cerveza Cristal 650ml");
        prod.setStockActual(new BigDecimal("10.000"));
        prod.setEstado(true);
        prod.setBodega(bodega);

        CompraDetalleDTO item = new CompraDetalleDTO();
        item.setIdProducto(20L);
        item.setCantidad(new BigDecimal("24.000"));
        item.setPrecioUnitario(new BigDecimal("5.50"));

        CompraDTO dto = new CompraDTO();
        dto.setIdProveedor(10L);
        dto.setComprobante("F001-009988");
        dto.setDetalles(List.of(item));

        when(proveedorRepository.findByIdProveedorAndBodega_IdBodega(10L, 1L)).thenReturn(Optional.of(prov));
        when(tenantService.getCurrentBodega()).thenReturn(bodega);
        when(compraRepository.existsByBodega_IdBodegaAndProveedor_IdProveedorAndComprobanteIgnoreCase(1L, 10L, "F001-009988"))
                .thenReturn(false);
        when(productoRepository.findByIdForUpdateAndBodega(20L, 1L)).thenReturn(Optional.of(prod));

        when(compraRepository.save(any(Compra.class))).thenAnswer(invocation -> {
            Compra c = invocation.getArgument(0);
            c.setIdCompra(100L);
            return c;
        });

        CompraDTO resultado = compraService.registrarCompra(dto);

        assertNotNull(resultado);
        assertEquals(100L, resultado.getIdCompra());
        assertEquals(new BigDecimal("132.00"), resultado.getTotal()); // 24 * 5.50 = 132.00
        assertEquals("F001-009988", resultado.getComprobante());

        // 1. Verifica incremento del stock: 10 + 24 = 34
        assertEquals(new BigDecimal("34.000"), prod.getStockActual());
        verify(productoRepository, times(1)).save(prod);

        // 2. Verifica movimiento ENTRADA en Kardex
        verify(movimientoInventarioRepository, times(1)).save(any(MovimientoInventario.class));

        // 3. Verifica guardado por lote de detalles
        verify(compraDetalleRepository, times(1)).saveAll(anyList());
    }

    @Test
    void testListarTodas_RetornaComprasConDetallesBatch() {
        Bodega bodega = new Bodega();
        bodega.setIdBodega(1L);

        Proveedor prov = new Proveedor();
        prov.setIdProveedor(1L);
        prov.setRazonSocial("Gloria");

        Compra compra = new Compra();
        compra.setIdCompra(1L);
        compra.setBodega(bodega);
        compra.setProveedor(prov);
        compra.setTotal(new BigDecimal("50.00"));

        when(compraRepository.findTop150ByBodega_IdBodegaOrderByFechaCompraDesc(1L))
                .thenReturn(List.of(compra));
        when(compraDetalleRepository.findByCompra_IdCompraIn(List.of(1L)))
                .thenReturn(List.of());

        List<CompraDTO> lista = compraService.listarTodas();

        assertNotNull(lista);
        assertEquals(1, lista.size());
        assertEquals(1L, lista.get(0).getIdCompra());
        assertEquals("Gloria", lista.get(0).getRazonSocialProveedor());
    }
}
