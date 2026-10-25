package com.bodega.backend.service;

import com.bodega.backend.dto.*;
import com.bodega.backend.entity.AbonoCredito;
import com.bodega.backend.entity.Cliente;
import com.bodega.backend.entity.Venta;
import com.bodega.backend.repository.AbonoCreditoRepository;
import com.bodega.backend.repository.ClienteRepository;
import com.bodega.backend.repository.VentaRepository;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class ClienteService {

    private final ClienteRepository clienteRepository;
    private final AbonoCreditoRepository abonoCreditoRepository;
    private final VentaRepository ventaRepository;
    private final TenantService tenantService;

    public ClienteService(ClienteRepository clienteRepository,
                          AbonoCreditoRepository abonoCreditoRepository,
                          VentaRepository ventaRepository,
                          TenantService tenantService) {
        this.clienteRepository = clienteRepository;
        this.abonoCreditoRepository = abonoCreditoRepository;
        this.ventaRepository = ventaRepository;
        this.tenantService = tenantService;
    }

    @Transactional(readOnly = true)
    public List<ClienteDTO> listar(String query, Boolean soloDeudores) {
        Long idBodega = tenantService.getCurrentBodegaId();
        List<Cliente> clientes;

        if (query != null && !query.trim().isEmpty()) {
            clientes = clienteRepository.buscarClientes(idBodega, query.trim());
        } else if (Boolean.TRUE.equals(soloDeudores)) {
            clientes = clienteRepository.findByBodega_IdBodegaAndEstadoTrueAndSaldoDeudorGreaterThanOrderBySaldoDeudorDesc(
                    idBodega, BigDecimal.ZERO);
        } else {
            clientes = clienteRepository.findByBodega_IdBodegaAndEstadoTrueOrderByNombreCompletoAsc(idBodega);
        }

        if (Boolean.TRUE.equals(soloDeudores)) {
            clientes = clientes.stream()
                    .filter(c -> c.getSaldoDeudor() != null && c.getSaldoDeudor().compareTo(BigDecimal.ZERO) > 0)
                    .collect(Collectors.toList());
        }

        return clientes.stream().map(this::mapToDTO).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public ClienteDTO obtenerPorId(Long idCliente) {
        Long idBodega = tenantService.getCurrentBodegaId();
        Cliente c = clienteRepository.findByIdClienteAndBodega_IdBodega(idCliente, idBodega)
                .orElseThrow(() -> new RuntimeException("Cliente no encontrado con ID: " + idCliente));
        return mapToDTO(c);
    }

    @Transactional
    public ClienteDTO crear(ClienteDTO dto) {
        Long idBodega = tenantService.getCurrentBodegaId();

        if (dto.getDocumento() != null && !dto.getDocumento().trim().isEmpty()) {
            String docTrim = dto.getDocumento().trim();
            java.util.Optional<Cliente> existente = clienteRepository.findByBodega_IdBodegaAndDocumentoAndEstadoTrue(idBodega, docTrim);
            if (existente.isPresent()) {
                throw new RuntimeException("Ya existe un cliente activo registrado con el documento: " + docTrim);
            }
        }

        Cliente c = new Cliente();
        c.setBodega(tenantService.getCurrentBodega());
        c.setNombreCompleto(dto.getNombreCompleto().trim());
        c.setDocumento(dto.getDocumento() != null ? dto.getDocumento().trim() : null);
        c.setTelefono(dto.getTelefono() != null ? dto.getTelefono().trim() : null);
        c.setDireccion(dto.getDireccion() != null ? dto.getDireccion().trim() : null);
        c.setLimiteCredito(dto.getLimiteCredito() != null ? dto.getLimiteCredito() : new BigDecimal("200.00"));
        c.setSaldoDeudor(BigDecimal.ZERO);
        c.setNotas(dto.getNotas() != null ? dto.getNotas().trim() : null);
        c.setEstado(true);

        Cliente guardado = clienteRepository.save(c);
        return mapToDTO(guardado);
    }

    @Transactional
    public ClienteDTO actualizar(Long idCliente, ClienteDTO dto) {
        Long idBodega = tenantService.getCurrentBodegaId();
        Cliente c = clienteRepository.findByIdClienteAndBodega_IdBodega(idCliente, idBodega)
                .orElseThrow(() -> new RuntimeException("Cliente no encontrado con ID: " + idCliente));

        c.setNombreCompleto(dto.getNombreCompleto().trim());
        c.setDocumento(dto.getDocumento() != null ? dto.getDocumento().trim() : null);
        c.setTelefono(dto.getTelefono() != null ? dto.getTelefono().trim() : null);
        c.setDireccion(dto.getDireccion() != null ? dto.getDireccion().trim() : null);
        if (dto.getLimiteCredito() != null) {
            c.setLimiteCredito(dto.getLimiteCredito());
        }
        c.setNotas(dto.getNotas() != null ? dto.getNotas().trim() : null);

        Cliente guardado = clienteRepository.save(c);
        return mapToDTO(guardado);
    }

    @Transactional
    public void eliminar(Long idCliente) {
        Long idBodega = tenantService.getCurrentBodegaId();
        Cliente c = clienteRepository.findByIdClienteAndBodega_IdBodega(idCliente, idBodega)
                .orElseThrow(() -> new RuntimeException("Cliente no encontrado con ID: " + idCliente));

        if (c.getSaldoDeudor() != null && c.getSaldoDeudor().compareTo(BigDecimal.ZERO) > 0) {
            throw new RuntimeException("No se puede eliminar un cliente con saldo deudor pendiente (S/ " +
                    c.getSaldoDeudor().toPlainString() + "). Registre el cobro antes de dar de baja.");
        }

        c.setEstado(false);
        clienteRepository.save(c);
    }

    @Transactional
    public AbonoCreditoDTO registrarAbono(Long idCliente, RegistrarAbonoDTO dto) {
        Long idBodega = tenantService.getCurrentBodegaId();
        Cliente c = clienteRepository.findByIdClienteAndBodega_IdBodega(idCliente, idBodega)
                .orElseThrow(() -> new RuntimeException("Cliente no encontrado con ID: " + idCliente));

        if (Boolean.FALSE.equals(c.getEstado())) {
            throw new RuntimeException("El cliente se encuentra inactivo.");
        }

        BigDecimal monto = dto.getMonto();
        if (monto == null || monto.compareTo(BigDecimal.ZERO) <= 0) {
            throw new RuntimeException("El monto a abonar debe ser mayor a cero.");
        }

        BigDecimal saldoAnterior = c.getSaldoDeudor() != null ? c.getSaldoDeudor() : BigDecimal.ZERO;
        if (saldoAnterior.compareTo(BigDecimal.ZERO) <= 0) {
            throw new RuntimeException("El cliente no tiene deuda pendiente para abonar.");
        }

        BigDecimal saldoRestante = saldoAnterior.subtract(monto);
        if (saldoRestante.compareTo(BigDecimal.ZERO) < 0) {
            saldoRestante = BigDecimal.ZERO;
        }

        c.setSaldoDeudor(saldoRestante);
        c.setFechaUltimoPago(OffsetDateTime.now());
        clienteRepository.save(c);

        AbonoCredito abono = new AbonoCredito();
        abono.setBodega(tenantService.getCurrentBodega());
        abono.setCliente(c);
        abono.setMonto(monto);
        abono.setMetodoPago(dto.getMetodoPago() != null ? dto.getMetodoPago() : "Efectivo");
        abono.setSaldoAnterior(saldoAnterior);
        abono.setSaldoRestante(saldoRestante);
        abono.setNotas(dto.getNotas());
        abono.setUsuarioRegistro(obtenerUsuarioActual());

        AbonoCredito guardado = abonoCreditoRepository.save(abono);
        guardado.setComprobanteNumero(String.format("AB-%06d", guardado.getIdAbono()));
        abonoCreditoRepository.save(guardado);

        return mapToAbonoDTO(guardado);
    }

    @Transactional(readOnly = true)
    public EstadoCuentaClienteDTO obtenerEstadoCuenta(Long idCliente) {
        Long idBodega = tenantService.getCurrentBodegaId();
        Cliente c = clienteRepository.findByIdClienteAndBodega_IdBodega(idCliente, idBodega)
                .orElseThrow(() -> new RuntimeException("Cliente no encontrado con ID: " + idCliente));

        List<Venta> ventasCredito = ventaRepository.findByCliente_IdClienteOrderByFechaVentaDesc(idCliente);
        List<AbonoCredito> abonos = abonoCreditoRepository.findByCliente_IdClienteOrderByFechaAbonoDesc(idCliente);

        BigDecimal totalCredito = ventasCredito.stream()
                .filter(v -> "COMPLETADA".equalsIgnoreCase(v.getEstado()))
                .map(Venta::getTotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal totalAbonos = abonos.stream()
                .map(AbonoCredito::getMonto)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        EstadoCuentaClienteDTO dto = new EstadoCuentaClienteDTO();
        dto.setCliente(mapToDTO(c));
        dto.setTotalVentasCredito(totalCredito);
        dto.setTotalAbonosRealizados(totalAbonos);
        dto.setAbonosRecientes(abonos.stream().map(this::mapToAbonoDTO).collect(Collectors.toList()));

        // Mapeo ligero de ventas de crédito recientes
        dto.setComprasCreditoRecientes(ventasCredito.stream().map(v -> {
            VentaDTO vDto = new VentaDTO();
            vDto.setIdVenta(v.getIdVenta());
            vDto.setTotal(v.getTotal());
            vDto.setFechaVenta(v.getFechaVenta());
            vDto.setSerieCorrelativo(v.getSerieCorrelativo());
            vDto.setMetodoPago(v.getMetodoPago());
            vDto.setEstado(v.getEstado());
            return vDto;
        }).collect(Collectors.toList()));

        return dto;
    }

    @Transactional(readOnly = true)
    public ResumenCreditosDTO obtenerResumenCreditos() {
        Long idBodega = tenantService.getCurrentBodegaId();
        List<Cliente> todos = clienteRepository.findByBodega_IdBodegaAndEstadoTrueOrderByNombreCompletoAsc(idBodega);

        long clientesConDeuda = 0;
        BigDecimal totalSaldoDeudor = BigDecimal.ZERO;

        for (Cliente c : todos) {
            if (c.getSaldoDeudor() != null && c.getSaldoDeudor().compareTo(BigDecimal.ZERO) > 0) {
                clientesConDeuda++;
                totalSaldoDeudor = totalSaldoDeudor.add(c.getSaldoDeudor());
            }
        }

        OffsetDateTime inicioMes = OffsetDateTime.now().withDayOfMonth(1).withHour(0).withMinute(0).withSecond(0);
        BigDecimal totalAbonosMes = abonoCreditoRepository.totalAbonosDesde(idBodega, inicioMes);
        if (totalAbonosMes == null) totalAbonosMes = BigDecimal.ZERO;

        ResumenCreditosDTO resumen = new ResumenCreditosDTO();
        resumen.setTotalClientes(todos.size());
        resumen.setClientesConDeuda(clientesConDeuda);
        resumen.setTotalSaldoDeudor(totalSaldoDeudor);
        resumen.setTotalAbonosMes(totalAbonosMes);

        return resumen;
    }

    private ClienteDTO mapToDTO(Cliente c) {
        ClienteDTO dto = new ClienteDTO();
        dto.setIdCliente(c.getIdCliente());
        dto.setIdBodega(c.getBodega() != null ? c.getBodega().getIdBodega() : null);
        dto.setDocumento(c.getDocumento());
        dto.setNombreCompleto(c.getNombreCompleto());
        dto.setTelefono(c.getTelefono());
        dto.setDireccion(c.getDireccion());
        dto.setLimiteCredito(c.getLimiteCredito());
        dto.setSaldoDeudor(c.getSaldoDeudor());

        BigDecimal limite = c.getLimiteCredito() != null ? c.getLimiteCredito() : BigDecimal.ZERO;
        BigDecimal deuda = c.getSaldoDeudor() != null ? c.getSaldoDeudor() : BigDecimal.ZERO;
        BigDecimal disponible = limite.subtract(deuda);
        if (disponible.compareTo(BigDecimal.ZERO) < 0) disponible = BigDecimal.ZERO;
        dto.setCreditoDisponible(disponible);

        dto.setNotas(c.getNotas());
        dto.setEstado(c.getEstado());
        dto.setFechaRegistro(c.getFechaRegistro());
        dto.setFechaUltimoPago(c.getFechaUltimoPago());
        return dto;
    }

    private AbonoCreditoDTO mapToAbonoDTO(AbonoCredito a) {
        AbonoCreditoDTO dto = new AbonoCreditoDTO();
        dto.setIdAbono(a.getIdAbono());
        dto.setIdCliente(a.getCliente() != null ? a.getCliente().getIdCliente() : null);
        dto.setNombreCliente(a.getCliente() != null ? a.getCliente().getNombreCompleto() : "");
        dto.setMonto(a.getMonto());
        dto.setMetodoPago(a.getMetodoPago());
        dto.setSaldoAnterior(a.getSaldoAnterior());
        dto.setSaldoRestante(a.getSaldoRestante());
        dto.setComprobanteNumero(a.getComprobanteNumero());
        dto.setNotas(a.getNotas());
        dto.setUsuarioRegistro(a.getUsuarioRegistro());
        dto.setFechaAbono(a.getFechaAbono());
        return dto;
    }

    private String obtenerUsuarioActual() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        return (auth != null && auth.getName() != null) ? auth.getName() : "SISTEMA";
    }
}
