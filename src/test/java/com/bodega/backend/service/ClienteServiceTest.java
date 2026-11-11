package com.bodega.backend.service;

import com.bodega.backend.dto.ClienteDTO;
import com.bodega.backend.dto.EstadoCuentaClienteDTO;
import com.bodega.backend.entity.AbonoCredito;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Cliente;
import com.bodega.backend.entity.Venta;
import com.bodega.backend.repository.AbonoCreditoRepository;
import com.bodega.backend.repository.ClienteRepository;
import com.bodega.backend.repository.VentaRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ClienteServiceTest {

    @Mock
    private ClienteRepository clienteRepository;

    @Mock
    private AbonoCreditoRepository abonoCreditoRepository;

    @Mock
    private VentaRepository ventaRepository;

    @Mock
    private TenantService tenantService;

    @InjectMocks
    private ClienteService clienteService;

    private Bodega bodega;
    private Cliente cliente;

    @BeforeEach
    void setUp() {
        bodega = new Bodega();
        bodega.setIdBodega(1L);

        cliente = new Cliente();
        cliente.setIdCliente(10L);
        cliente.setBodega(bodega);
        cliente.setDocumento("12345678");
        cliente.setNombreCompleto("Rosa Quispe");
        cliente.setLimiteCredito(new BigDecimal("200.00"));
        cliente.setSaldoDeudor(new BigDecimal("110.00"));
        cliente.setEstado(true);
    }

    @Test
    void testObtenerEstadoCuenta_UsaConsultasSqlCreditoYAbonosPorTenant() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(clienteRepository.findByIdClienteAndBodega_IdBodega(10L, 1L))
                .thenReturn(Optional.of(cliente));

        Venta ventaCredito = new Venta();
        ventaCredito.setIdVenta(501L);
        ventaCredito.setTotal(new BigDecimal("150.00"));
        ventaCredito.setMetodoPago("CREDITO");
        ventaCredito.setEstado("COMPLETADA");
        ventaCredito.setFechaVenta(OffsetDateTime.now());

        AbonoCredito abono = new AbonoCredito();
        abono.setIdAbono(301L);
        abono.setCliente(cliente);
        abono.setBodega(bodega);
        abono.setMonto(new BigDecimal("40.00"));
        abono.setSaldoAnterior(new BigDecimal("150.00"));
        abono.setSaldoRestante(new BigDecimal("110.00"));
        abono.setFechaAbono(OffsetDateTime.now());

        when(ventaRepository.findVentasCreditoRecientesByClienteAndBodega(eq(10L), eq(1L), any()))
                .thenReturn(List.of(ventaCredito));
        when(abonoCreditoRepository.findTop50ByCliente_IdClienteAndBodega_IdBodegaOrderByFechaAbonoDesc(10L, 1L))
                .thenReturn(List.of(abono));
        when(ventaRepository.sumTotalCreditoByClienteAndBodega(10L, 1L))
                .thenReturn(new BigDecimal("150.00"));
        when(abonoCreditoRepository.sumTotalAbonosByClienteAndBodega(10L, 1L))
                .thenReturn(new BigDecimal("40.00"));

        EstadoCuentaClienteDTO estado = clienteService.obtenerEstadoCuenta(10L);

        assertEquals(new BigDecimal("150.00"), estado.getTotalVentasCredito());
        assertEquals(new BigDecimal("40.00"), estado.getTotalAbonosRealizados());
        assertEquals(1, estado.getComprasCreditoRecientes().size());
        assertEquals(1, estado.getAbonosRecientes().size());

        verify(ventaRepository, never()).findByCliente_IdClienteOrderByFechaVentaDesc(any());
        verify(abonoCreditoRepository, never()).findByCliente_IdClienteOrderByFechaAbonoDesc(any());
    }

    @Test
    void testActualizarCliente_DocumentoDuplicadoEnOtroClienteActivo_LanzaExcepcion() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(clienteRepository.findByIdClienteAndBodega_IdBodega(10L, 1L))
                .thenReturn(Optional.of(cliente));
        when(clienteRepository.existsByBodega_IdBodegaAndDocumentoIgnoreCaseAndEstadoTrueAndIdClienteNot(
                1L, "87654321", 10L)).thenReturn(true);

        ClienteDTO dto = new ClienteDTO();
        dto.setNombreCompleto("Rosa Quispe");
        dto.setDocumento("87654321");

        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> clienteService.actualizar(10L, dto));
        assertTrue(ex.getMessage().contains("87654321"));
        verify(clienteRepository, never()).save(any());
    }
}
