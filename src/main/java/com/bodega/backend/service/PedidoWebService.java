package com.bodega.backend.service;

import com.bodega.backend.dto.*;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.PedidoWeb;
import com.bodega.backend.entity.PedidoWebDetalle;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.PedidoWebRepository;
import com.bodega.backend.repository.ProductoRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Service
public class PedidoWebService {

    private static final Logger log = LoggerFactory.getLogger(PedidoWebService.class);

    private final PedidoWebRepository pedidoWebRepository;
    private final ProductoRepository productoRepository;

    // Control de revisiones en memoria ultraligero:
    // Evita consultas a PostgreSQL cuando no hay nuevos pedidos (0% DB overhead en sondeo POS)
    private final ConcurrentHashMap<Long, Long> revisionPorBodega = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<Long, Long> conteoPendientesPorBodega = new ConcurrentHashMap<>();
    private final SecureRandom random = new SecureRandom();

    public PedidoWebService(PedidoWebRepository pedidoWebRepository,
                            ProductoRepository productoRepository) {
        this.pedidoWebRepository = pedidoWebRepository;
        this.productoRepository = productoRepository;
    }

    /**
     * Consulta ultrarrápida en memoria (< 1ms). Si no hay cambios respecto a la última
     * revisión enviada por la caja, responde de inmediato sin tocar PostgreSQL.
     */
    @Transactional(readOnly = true)
    public RevisionPedidosDTO verificarRevision(Long idBodega, Long ultimaRevision) {
        if (idBodega == null) {
            return new RevisionPedidosDTO(false, 0L, 0L, System.currentTimeMillis());
        }

        Long currentRev = revisionPorBodega.getOrDefault(idBodega, 0L);
        Long conteo = conteoPendientesPorBodega.computeIfAbsent(idBodega, k ->
                pedidoWebRepository.countByBodegaIdBodegaAndEstado(k, "PENDIENTE")
        );

        boolean hayCambio = (ultimaRevision == null) || (currentRev > ultimaRevision);

        return RevisionPedidosDTO.builder()
                .hayCambio(hayCambio)
                .revision(currentRev)
                .conteoPendientes(conteo)
                .timestamp(System.currentTimeMillis())
                .build();
    }

    /**
     * Registra un pedido web proveniente del catálogo digital público de la bodega.
     */
    @Transactional
    public PedidoWebDTO registrarPedidoWebPublico(Bodega bodega, PedidoWebCreacionDTO dto) {
        if (bodega == null) {
            throw new IllegalArgumentException("Bodega no especificada");
        }

        String codigo = dto.getCodigoPedido();
        if (codigo == null || codigo.isBlank()) {
            codigo = dto.getIdPedido();
        }
        if (codigo == null || codigo.isBlank()) {
            int numRandom = 1000 + random.nextInt(9000);
            codigo = "#W-" + numRandom;
        }

        String cliente = dto.getNombreCliente();
        if (cliente == null || cliente.isBlank()) {
            cliente = "Cliente Web";
        }

        PedidoWeb pedido = PedidoWeb.builder()
                .bodega(bodega)
                .codigoPedido(codigo.trim())
                .nombreCliente(cliente.trim())
                .telefonoCliente(dto.getTelefonoCliente() != null ? dto.getTelefonoCliente().trim() : null)
                .notas(dto.getNotas() != null ? dto.getNotas().trim() : null)
                .total(dto.getTotal() != null ? dto.getTotal() : BigDecimal.ZERO)
                .ahorroPromociones(dto.getAhorroPromociones() != null ? dto.getAhorroPromociones() : BigDecimal.ZERO)
                .incluyeRetornables(dto.getIncluyeRetornables() != null && dto.getIncluyeRetornables())
                .estado("PENDIENTE")
                .detalles(new ArrayList<>())
                .build();

        if (dto.getItems() != null) {
            Set<Long> productIds = dto.getItems().stream()
                    .map(PedidoWebDetalleCreacionDTO::getIdProducto)
                    .filter(id -> id != null && id > 0)
                    .collect(Collectors.toSet());
            Map<Long, Producto> productosPorId = new HashMap<>();
            if (!productIds.isEmpty()) {
                for (Producto p : productoRepository.findAllById(productIds)) {
                    if (p != null && p.getIdProducto() != null
                            && (p.getBodega() == null || bodega.getIdBodega().equals(p.getBodega().getIdBodega()))) {
                        productosPorId.put(p.getIdProducto(), p);
                    }
                }
            }

            for (PedidoWebDetalleCreacionDTO itemDto : dto.getItems()) {
                Producto prod = (itemDto.getIdProducto() != null && itemDto.getIdProducto() > 0)
                        ? productosPorId.get(itemDto.getIdProducto())
                        : null;

                PedidoWebDetalle det = PedidoWebDetalle.builder()
                        .producto(prod)
                        .nombreProducto(itemDto.getNombreFinal())
                        .cantidad(itemDto.getCantidad() != null ? itemDto.getCantidad() : BigDecimal.ONE)
                        .precioUnitario(itemDto.getPrecioUnitario() != null ? itemDto.getPrecioUnitario() : BigDecimal.ZERO)
                        .subtotal(itemDto.getSubtotal() != null ? itemDto.getSubtotal() : BigDecimal.ZERO)
                        .badge(itemDto.getBadge() != null ? itemDto.getBadge().trim() : null)
                        .build();

                pedido.agregarDetalle(det);
            }
        }

        PedidoWeb guardado = pedidoWebRepository.save(pedido);

        // Notificar cambio en memoria para despertar inmediatamente a los POS conectados
        Long idBodega = bodega.getIdBodega();
        revisionPorBodega.compute(idBodega, (k, v) -> v == null ? 1L : v + 1L);
        conteoPendientesPorBodega.compute(idBodega, (k, v) -> v == null ? 1L : v + 1L);

        log.info("Pedido web registrado exitosamente [id={}, codigo={}, bodega={}]",
                guardado.getIdPedidoWeb(), guardado.getCodigoPedido(), idBodega);

        return toDTO(guardado);
    }

    /**
     * Lista los pedidos web de la bodega ordenados por fecha descendente.
     */
    @Transactional(readOnly = true)
    public List<PedidoWebDTO> listarPedidos(Long idBodega, String estado, int limite) {
        int limitSeguro = Math.max(1, Math.min(limite, 100));
        PageRequest pageRequest = PageRequest.of(0, limitSeguro);

        List<PedidoWeb> lista;
        if (estado != null && !estado.isBlank() && !"TODOS".equalsIgnoreCase(estado)) {
            lista = pedidoWebRepository.findByBodegaIdBodegaAndEstadoOrderByFechaCreacionDesc(
                    idBodega, estado.toUpperCase(Locale.ROOT), pageRequest
            );
        } else {
            lista = pedidoWebRepository.findByBodegaIdBodegaOrderByFechaCreacionDesc(
                    idBodega, pageRequest
            );
        }

        return lista.stream().map(this::toDTO).collect(Collectors.toList());
    }

    /**
     * Actualiza el estado de un pedido (ej. PENDIENTE -> CARGADO_EN_POS -> COMPLETADO).
     */
    @Transactional
    public PedidoWebDTO actualizarEstado(Long idBodega, Long idPedidoWeb, String nuevoEstado) {
        PedidoWeb pedido = pedidoWebRepository.findByIdPedidoWebAndBodegaIdBodega(idPedidoWeb, idBodega)
                .orElseThrow(() -> new IllegalArgumentException("Pedido web no encontrado para esta bodega"));

        String estadoAntiguo = pedido.getEstado();
        String estadoLimpio = nuevoEstado != null ? nuevoEstado.toUpperCase(Locale.ROOT).trim() : "COMPLETADO";

        pedido.setEstado(estadoLimpio);
        pedido.setFechaActualizacion(OffsetDateTime.now());
        PedidoWeb actualizado = pedidoWebRepository.save(pedido);

        // Ajustar conteo de pendientes en memoria si cambió el estado
        if ("PENDIENTE".equalsIgnoreCase(estadoAntiguo) && !"PENDIENTE".equalsIgnoreCase(estadoLimpio)) {
            conteoPendientesPorBodega.compute(idBodega, (k, v) -> (v == null || v <= 1L) ? 0L : v - 1L);
        } else if (!"PENDIENTE".equalsIgnoreCase(estadoAntiguo) && "PENDIENTE".equalsIgnoreCase(estadoLimpio)) {
            conteoPendientesPorBodega.compute(idBodega, (k, v) -> v == null ? 1L : v + 1L);
        }

        // Incrementar revisión en memoria
        revisionPorBodega.compute(idBodega, (k, v) -> v == null ? 1L : v + 1L);

        return toDTO(actualizado);
    }

    /**
     * Búsqueda por código de pedido (#W-XXXX), nombre de cliente o teléfono.
     */
    @Transactional(readOnly = true)
    public List<PedidoWebDTO> buscarPedidos(Long idBodega, String query, int limite) {
        if (query == null || query.isBlank()) {
            return listarPedidos(idBodega, null, limite);
        }
        int limitSeguro = Math.max(1, Math.min(limite, 50));
        return pedidoWebRepository.buscarPorFiltro(idBodega, query.trim(), PageRequest.of(0, limitSeguro))
                .stream().map(this::toDTO).collect(Collectors.toList());
    }

    /**
     * Elimina un pedido web.
     */
    @Transactional
    public void eliminarPedido(Long idBodega, Long idPedidoWeb) {
        PedidoWeb pedido = pedidoWebRepository.findByIdPedidoWebAndBodegaIdBodega(idPedidoWeb, idBodega)
                .orElseThrow(() -> new IllegalArgumentException("Pedido web no encontrado para esta bodega"));

        if ("PENDIENTE".equalsIgnoreCase(pedido.getEstado())) {
            conteoPendientesPorBodega.compute(idBodega, (k, v) -> (v == null || v <= 1L) ? 0L : v - 1L);
        }

        pedidoWebRepository.delete(pedido);
        revisionPorBodega.compute(idBodega, (k, v) -> v == null ? 1L : v + 1L);
    }

    public PedidoWebDTO toDTO(PedidoWeb p) {
        if (p == null) return null;

        List<PedidoWebDetalleDTO> items = new ArrayList<>();
        if (p.getDetalles() != null) {
            for (PedidoWebDetalle d : p.getDetalles()) {
                items.add(PedidoWebDetalleDTO.builder()
                        .idDetallePedidoWeb(d.getIdDetallePedidoWeb())
                        .idProducto(d.getProducto() != null ? d.getProducto().getIdProducto() : null)
                        .nombre(d.getNombreProducto())
                        .cantidad(d.getCantidad())
                        .precioUnitario(d.getPrecioUnitario())
                        .subtotal(d.getSubtotal())
                        .badge(d.getBadge())
                        .build());
            }
        }

        return PedidoWebDTO.builder()
                .idPedidoWeb(p.getIdPedidoWeb())
                .idPedido(p.getCodigoPedido())
                .codigoPedido(p.getCodigoPedido())
                .fecha(p.getFechaCreacion())
                .nombreCliente(p.getNombreCliente())
                .telefonoCliente(p.getTelefonoCliente())
                .notas(p.getNotas())
                .total(p.getTotal())
                .ahorroPromociones(p.getAhorroPromociones())
                .incluyeRetornables(p.getIncluyeRetornables())
                .estado(p.getEstado())
                .items(items)
                .build();
    }
}
