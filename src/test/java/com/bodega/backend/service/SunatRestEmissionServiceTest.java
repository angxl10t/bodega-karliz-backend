package com.bodega.backend.service;

import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.entity.Venta;
import com.bodega.backend.entity.VentaDetalle;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

public class SunatRestEmissionServiceTest {

    private SunatRestEmissionService sunatService;
    private Bodega bodega;
    private Venta venta;
    private List<VentaDetalle> detalles;

    @BeforeEach
    void setUp() {
        sunatService = new SunatRestEmissionService();

        bodega = new Bodega();
        bodega.setIdBodega(1L);
        bodega.setNombreComercial("Bodega Central");
        bodega.setRucDni("20100070970");
        bodega.setFacturacionSunatActiva(true);

        Producto producto = new Producto();
        producto.setIdProducto(10L);
        producto.setNombre("Leche Gloria 400g");

        VentaDetalle det = new VentaDetalle();
        det.setIdDetalleVenta(1L);
        det.setProducto(producto);
        det.setCantidad(new BigDecimal("2.000"));
        det.setPrecioUnitario(new BigDecimal("4.50"));
        det.setSubtotal(new BigDecimal("9.00"));

        detalles = new ArrayList<>();
        detalles.add(det);

        venta = new Venta();
        venta.setIdVenta(100L);
        venta.setBodega(bodega);
        venta.setTipoComprobante("BOLETA_ELECTRONICA");
        venta.setSerieCorrelativo("B001-00000001");
        venta.setTotal(new BigDecimal("9.00"));
        venta.setFechaVenta(OffsetDateTime.now());
        venta.setClienteNombre("Juan Perez");
        venta.setClienteDocumento("71234567");
    }

    @Test
    void testDespacharComprobante_NullOListaVacia_NoHaceNada() {
        sunatService.despacharComprobante(null, detalles, bodega);
        sunatService.despacharComprobante(venta, null, bodega);
        sunatService.despacharComprobante(venta, List.of(), bodega);

        assertNull(venta.getEstadoSunat());
    }

    @Test
    void testDespacharComprobante_ComprobanteNoElectronico_Ignora() {
        venta.setTipoComprobante("TICKET");

        sunatService.despacharComprobante(venta, detalles, bodega);

        assertNull(venta.getEstadoSunat());
    }

    @Test
    void testDespacharComprobante_ModoPruebasSimulado_AceptaEnBeta() {
        ReflectionTestUtils.setField(sunatService, "modoPruebas", true);
        ReflectionTestUtils.setField(sunatService, "globalApiToken", "");

        sunatService.despacharComprobante(venta, detalles, bodega);

        assertEquals("ACEPTADO_BETA", venta.getEstadoSunat());
        assertNotNull(venta.getSunatHash());
        assertTrue(venta.getSunatMensaje().contains("Beta SUNAT"));
    }

    @Test
    void testDespacharComprobante_SinTokenModoProduccion_QuedaPendienteEnvio() {
        ReflectionTestUtils.setField(sunatService, "modoPruebas", false);
        ReflectionTestUtils.setField(sunatService, "globalApiToken", "");

        sunatService.despacharComprobante(venta, detalles, bodega);

        assertEquals("PENDIENTE_ENVIO", venta.getEstadoSunat());
        assertTrue(venta.getSunatMensaje().contains("Token de API SUNAT no configurado"));
    }
}
