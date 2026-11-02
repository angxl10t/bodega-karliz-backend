package com.bodega.backend.service;

import com.bodega.backend.dto.DevolverGarantiaDTO;
import com.bodega.backend.dto.GarantiaBotellaDTO;
import com.bodega.backend.dto.RegistrarGarantiaDTO;
import com.bodega.backend.dto.ResumenGarantiasDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Cliente;
import com.bodega.backend.entity.GarantiaBotella;
import com.bodega.backend.exception.ResourceNotFoundException;
import com.bodega.backend.repository.ClienteRepository;
import com.bodega.backend.repository.GarantiaBotellaRepository;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class GarantiaBotellaService {

    private final GarantiaBotellaRepository garantiaRepository;
    private final ClienteRepository clienteRepository;
    private final TenantService tenantService;

    public GarantiaBotellaService(GarantiaBotellaRepository garantiaRepository,
                                  ClienteRepository clienteRepository,
                                  TenantService tenantService) {
        this.garantiaRepository = garantiaRepository;
        this.clienteRepository = clienteRepository;
        this.tenantService = tenantService;
    }

    @Transactional(readOnly = true)
    public List<GarantiaBotellaDTO> listar(String estado, String query) {
        Long idBodega = tenantService.getCurrentBodegaId();
        List<GarantiaBotella> list;

        String estadoFiltro = (estado != null && !estado.trim().isEmpty() && !"TODAS".equalsIgnoreCase(estado))
                ? estado.trim().toUpperCase() : null;

        if (query != null && !query.trim().isEmpty()) {
            list = garantiaRepository.buscarGarantias(idBodega, estadoFiltro, query.trim());
        } else if (estadoFiltro != null) {
            list = garantiaRepository.findByBodega_IdBodegaAndEstadoOrderByFechaRegistroDesc(idBodega, estadoFiltro);
        } else {
            list = garantiaRepository.findByBodega_IdBodegaOrderByFechaRegistroDesc(idBodega);
        }

        return list.stream().map(this::mapToDTO).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public GarantiaBotellaDTO obtenerPorId(Long id) {
        Long idBodega = tenantService.getCurrentBodegaId();
        GarantiaBotella g = garantiaRepository.findByIdGarantiaAndBodega_IdBodega(id, idBodega)
                .orElseThrow(() -> new ResourceNotFoundException("Garantía de botellas no encontrada con id: " + id));
        return mapToDTO(g);
    }

    @Transactional
    public GarantiaBotellaDTO crear(RegistrarGarantiaDTO dto) {
        Bodega bodega = tenantService.getCurrentBodega();

        Cliente cliente = null;
        if (dto.getIdCliente() != null) {
            cliente = clienteRepository.findByIdClienteAndBodega_IdBodega(dto.getIdCliente(), bodega.getIdBodega())
                    .orElse(null);
        }

        String telefono = dto.getTelefono();
        if ((telefono == null || telefono.isBlank()) && cliente != null) {
            telefono = cliente.getTelefono();
        }

        String nombre = dto.getNombrePersona() != null ? dto.getNombrePersona().trim() : "";
        if (nombre.isBlank() && cliente != null) {
            nombre = cliente.getNombreCompleto();
        }

        String usuario = getUsuarioActual();

        GarantiaBotella g = new GarantiaBotella();
        g.setBodega(bodega);
        g.setCliente(cliente);
        g.setNombrePersona(nombre);
        g.setTelefono(telefono);
        g.setCantidadBotellas(dto.getCantidadBotellas() != null ? dto.getCantidadBotellas() : 1);
        g.setMontoGarantia(dto.getMontoGarantia() != null ? dto.getMontoGarantia() : BigDecimal.ZERO);
        g.setTipoBotella(dto.getTipoBotella() != null && !dto.getTipoBotella().isBlank()
                ? dto.getTipoBotella().trim() : "Botellas de Vidrio");
        g.setNotas(dto.getNotas());
        g.setEstado("PENDIENTE");
        g.setBotellasDevueltas(0);
        g.setMontoDevuelto(BigDecimal.ZERO);
        g.setUsuarioRegistro(usuario);

        g = garantiaRepository.save(g);
        return mapToDTO(g);
    }

    @Transactional
    public GarantiaBotellaDTO devolver(Long idGarantia, DevolverGarantiaDTO dto) {
        Long idBodega = tenantService.getCurrentBodegaId();
        // Bloqueo pesimista (PESSIMISTIC_WRITE) para evitar condiciones de carrera y dobles reembolsos concurrentes
        GarantiaBotella g = garantiaRepository.findByIdForUpdateAndBodega(idGarantia, idBodega)
                .or(() -> garantiaRepository.findByIdGarantiaAndBodega_IdBodega(idGarantia, idBodega))
                .orElseThrow(() -> new ResourceNotFoundException("Garantía no encontrada con id: " + idGarantia));

        if ("DEVUELTO".equalsIgnoreCase(g.getEstado())) {
            throw new IllegalStateException("Esta garantía ya fue devuelta en su totalidad.");
        }

        int totalBotellas = g.getCantidadBotellas() != null ? g.getCantidadBotellas() : 1;
        int devueltasActuales = g.getBotellasDevueltas() != null ? g.getBotellasDevueltas() : 0;
        int pendientes = Math.max(0, totalBotellas - devueltasActuales);

        int aDevolver = (dto != null && dto.getCantidadDevolver() != null && dto.getCantidadDevolver() > 0)
                ? Math.min(dto.getCantidadDevolver(), pendientes)
                : pendientes;

        BigDecimal totalGarantia = g.getMontoGarantia() != null ? g.getMontoGarantia() : BigDecimal.ZERO;
        BigDecimal devueltoActual = g.getMontoDevuelto() != null ? g.getMontoDevuelto() : BigDecimal.ZERO;
        BigDecimal montoRestante = totalGarantia.subtract(devueltoActual).max(BigDecimal.ZERO);

        BigDecimal montoAEntregar;
        if (dto != null && dto.getMontoEntregado() != null && dto.getMontoEntregado().compareTo(BigDecimal.ZERO) > 0) {
            montoAEntregar = dto.getMontoEntregado().min(montoRestante);
        } else if (pendientes > 0) {
            if (aDevolver >= pendientes) {
                montoAEntregar = montoRestante;
            } else {
                montoAEntregar = montoRestante.multiply(new BigDecimal(aDevolver))
                        .divide(new BigDecimal(pendientes), 2, RoundingMode.HALF_UP);
            }
        } else {
            montoAEntregar = montoRestante;
        }

        g.setBotellasDevueltas(devueltasActuales + aDevolver);
        g.setMontoDevuelto(devueltoActual.add(montoAEntregar));
        g.setFechaDevolucion(OffsetDateTime.now());

        if (g.getBotellasDevueltas() >= totalBotellas || g.getMontoDevuelto().compareTo(totalGarantia) >= 0) {
            g.setEstado("DEVUELTO");
        }

        if (dto != null && dto.getNotas() != null && !dto.getNotas().isBlank()) {
            String notaAnterior = g.getNotas() != null ? g.getNotas() + " | " : "";
            g.setNotas(notaAnterior + "Devolución: " + dto.getNotas().trim());
        }

        g = garantiaRepository.save(g);
        return mapToDTO(g);
    }

    @Transactional
    public void eliminar(Long id) {
        Long idBodega = tenantService.getCurrentBodegaId();
        GarantiaBotella g = garantiaRepository.findByIdGarantiaAndBodega_IdBodega(id, idBodega)
                .orElseThrow(() -> new ResourceNotFoundException("Garantía no encontrada con id: " + id));
        garantiaRepository.delete(g);
    }

    @Transactional(readOnly = true)
    public ResumenGarantiasDTO obtenerResumen() {
        Long idBodega = tenantService.getCurrentBodegaId();
        List<GarantiaBotella> pendientes = garantiaRepository.findByBodega_IdBodegaAndEstadoOrderByFechaRegistroDesc(idBodega, "PENDIENTE");

        BigDecimal totalCustodia = BigDecimal.ZERO;
        int botellasPendientes = 0;

        for (GarantiaBotella g : pendientes) {
            BigDecimal tg = g.getMontoGarantia() != null ? g.getMontoGarantia() : BigDecimal.ZERO;
            BigDecimal md = g.getMontoDevuelto() != null ? g.getMontoDevuelto() : BigDecimal.ZERO;
            totalCustodia = totalCustodia.add(tg.subtract(md).max(BigDecimal.ZERO));

            int tb = g.getCantidadBotellas() != null ? g.getCantidadBotellas() : 0;
            int bd = g.getBotellasDevueltas() != null ? g.getBotellasDevueltas() : 0;
            botellasPendientes += Math.max(0, tb - bd);
        }

        // Devoluciones del mes actual en hora de Perú (America/Lima)
        java.time.ZoneId zonePeru = java.time.ZoneId.of("America/Lima");
        OffsetDateTime inicioMes = java.time.LocalDate.now(zonePeru).withDayOfMonth(1)
                .atStartOfDay(zonePeru).toOffsetDateTime();
        List<GarantiaBotella> devolucionesMes = garantiaRepository.findDevolucionesDesde(idBodega, inicioMes);

        BigDecimal totalDevueltoMes = devolucionesMes.stream()
                .map(g -> g.getMontoDevuelto() != null ? g.getMontoDevuelto() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        int botellasDevueltasMes = devolucionesMes.stream()
                .mapToInt(g -> g.getBotellasDevueltas() != null ? g.getBotellasDevueltas() : 0)
                .sum();

        return ResumenGarantiasDTO.builder()
                .totalDineroCustodia(totalCustodia)
                .botellasPendientes(botellasPendientes)
                .personasPendientes((long) pendientes.size())
                .totalDevueltoMes(totalDevueltoMes)
                .botellasDevueltasMes(botellasDevueltasMes)
                .build();
    }

    private GarantiaBotellaDTO mapToDTO(GarantiaBotella g) {
        int totalBotellas = g.getCantidadBotellas() != null ? g.getCantidadBotellas() : 1;
        int devueltas = g.getBotellasDevueltas() != null ? g.getBotellasDevueltas() : 0;
        int restantes = Math.max(0, totalBotellas - devueltas);

        BigDecimal totalMonto = g.getMontoGarantia() != null ? g.getMontoGarantia() : BigDecimal.ZERO;
        BigDecimal devuelto = g.getMontoDevuelto() != null ? g.getMontoDevuelto() : BigDecimal.ZERO;
        BigDecimal montoRestante = totalMonto.subtract(devuelto).max(BigDecimal.ZERO);

        return GarantiaBotellaDTO.builder()
                .idGarantia(g.getIdGarantia())
                .idBodega(g.getBodega() != null ? g.getBodega().getIdBodega() : null)
                .idCliente(g.getCliente() != null ? g.getCliente().getIdCliente() : null)
                .nombrePersona(g.getNombrePersona())
                .telefono(g.getTelefono())
                .cantidadBotellas(totalBotellas)
                .montoGarantia(totalMonto)
                .tipoBotella(g.getTipoBotella())
                .notas(g.getNotas())
                .estado(g.getEstado())
                .botellasDevueltas(devueltas)
                .montoDevuelto(devuelto)
                .botellasRestantes(restantes)
                .montoRestante(montoRestante)
                .fechaRegistro(g.getFechaRegistro())
                .fechaDevolucion(g.getFechaDevolucion())
                .usuarioRegistro(g.getUsuarioRegistro())
                .build();
    }

    private String getUsuarioActual() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) {
            return auth.getName();
        }
        return "admin";
    }
}
