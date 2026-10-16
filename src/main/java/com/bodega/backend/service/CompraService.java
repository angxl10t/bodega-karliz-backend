package com.bodega.backend.service;

import com.bodega.backend.dto.CompraDTO;
import com.bodega.backend.dto.CompraDetalleDTO;
import com.bodega.backend.entity.*;
import com.bodega.backend.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class CompraService {

    private final CompraRepository compraRepository;
    private final CompraDetalleRepository compraDetalleRepository;
    private final ProveedorRepository proveedorRepository;
    private final ProductoRepository productoRepository;
    private final MovimientoInventarioRepository movimientoInventarioRepository;
    private final TenantService tenantService;

    public CompraService(CompraRepository compraRepository,
                         CompraDetalleRepository compraDetalleRepository,
                         ProveedorRepository proveedorRepository,
                         ProductoRepository productoRepository,
                         MovimientoInventarioRepository movimientoInventarioRepository,
                         TenantService tenantService) {
        this.compraRepository = compraRepository;
        this.compraDetalleRepository = compraDetalleRepository;
        this.proveedorRepository = proveedorRepository;
        this.productoRepository = productoRepository;
        this.movimientoInventarioRepository = movimientoInventarioRepository;
        this.tenantService = tenantService;
    }

    // ACCIDENTAL DATA LOSS PREVENTION: Usamos @Transactional para que todo sea "Todo o Nada"
    @Transactional
    public CompraDTO registrarCompra(CompraDTO dto) {
        Long idBodega = tenantService.getCurrentBodegaId();

        Proveedor proveedor = proveedorRepository.findByIdProveedorAndBodega_IdBodega(dto.getIdProveedor(), idBodega)
                .orElseThrow(() -> new RuntimeException("Proveedor no encontrado en esta bodega"));

        if (Boolean.FALSE.equals(proveedor.getEstado())) {
            throw new RuntimeException("No se puede registrar compra para el proveedor inactivo o dado de baja: " + proveedor.getRazonSocial());
        }

        String comprobanteTrim = (dto.getComprobante() != null && !dto.getComprobante().isBlank()) 
                ? dto.getComprobante().replaceAll("[\\p{Cntrl}]", " ").trim() 
                : null;
        if (comprobanteTrim != null && comprobanteTrim.length() > 50) {
            comprobanteTrim = comprobanteTrim.substring(0, 50);
        }

        if (comprobanteTrim != null && compraRepository.existsByBodega_IdBodegaAndProveedor_IdProveedorAndComprobanteIgnoreCase(idBodega, proveedor.getIdProveedor(), comprobanteTrim)) {
            throw new RuntimeException("Ya existe una compra registrada con el comprobante '" + comprobanteTrim + "' para el proveedor " + proveedor.getRazonSocial());
        }

        String usuarioActual = obtenerUsuarioActual();

        // 1. Crear Cabecera con Aislamiento de Bodega y Auditoría de Operador
        Compra compra = new Compra();
        compra.setBodega(tenantService.getCurrentBodega());
        compra.setProveedor(proveedor);
        compra.setComprobante(comprobanteTrim);
        compra.setUsuarioRegistro(usuarioActual);
        
        BigDecimal totalCompra = BigDecimal.ZERO;
        
        // 2. Consolidación atómica: fusionar cantidades repetidas del mismo idProducto
        Map<Long, BigDecimal> cantidadesConsolidadas = new LinkedHashMap<>();
        Map<Long, BigDecimal> preciosPorProducto = new LinkedHashMap<>();

        for (CompraDetalleDTO detDto : dto.getDetalles()) {
            if (detDto.getIdProducto() == null) {
                throw new RuntimeException("Cada ítem de la compra debe especificar el producto correspondiente.");
            }
            if (detDto.getCantidad() == null || detDto.getCantidad().compareTo(BigDecimal.ZERO) <= 0) {
                throw new RuntimeException("La cantidad ingresada para cada producto en la compra debe ser mayor a cero.");
            }
            if (detDto.getPrecioUnitario() == null || detDto.getPrecioUnitario().compareTo(BigDecimal.ZERO) <= 0) {
                throw new RuntimeException("El costo unitario para cada producto en la compra debe ser mayor a cero.");
            }
            cantidadesConsolidadas.merge(detDto.getIdProducto(), detDto.getCantidad(), BigDecimal::add);
            preciosPorProducto.putIfAbsent(detDto.getIdProducto(), detDto.getPrecioUnitario());
        }

        if (cantidadesConsolidadas.isEmpty()) {
            throw new RuntimeException("La compra debe contener al menos un producto con cantidad válida.");
        }

        List<Long> idsProductosOrdenados = new ArrayList<>(cantidadesConsolidadas.keySet());
        Collections.sort(idsProductosOrdenados);

        List<CompraDetalle> detallesGuardados = new ArrayList<>();
        
        for (Long idProd : idsProductosOrdenados) {
            BigDecimal cantidadTotal = cantidadesConsolidadas.get(idProd).setScale(3, java.math.RoundingMode.HALF_UP);
            BigDecimal precioUnitario = preciosPorProducto.get(idProd).setScale(2, java.math.RoundingMode.HALF_UP);

            if (precioUnitario.compareTo(BigDecimal.ZERO) <= 0) {
                throw new RuntimeException("El precio unitario de compra debe ser mayor a cero.");
            }

            // Bloqueo pesimista exclusivo restringido al tenant actual
            Producto producto = productoRepository.findByIdForUpdateAndBodega(idProd, idBodega)
                    .orElseThrow(() -> new RuntimeException("Producto no encontrado en esta bodega: " + idProd));

            // Validación de Integridad de Negocio: No permitir ingreso de inventario para productos inactivos o descontinuados
            if (Boolean.FALSE.equals(producto.getEstado())) {
                throw new RuntimeException("No se puede registrar compra para el producto dado de baja o inactivo: " + producto.getNombre());
            }

            // Backend calcula el subtotal con redondeo comercial exacto
            BigDecimal subtotal = cantidadTotal.multiply(precioUnitario).setScale(2, java.math.RoundingMode.HALF_UP);
            totalCompra = totalCompra.add(subtotal);

            CompraDetalle detalle = new CompraDetalle();
            detalle.setProducto(producto);
            detalle.setCantidad(cantidadTotal);
            detalle.setPrecioUnitario(precioUnitario);
            detalle.setSubtotal(subtotal);
            detallesGuardados.add(detalle);

            // 3. Actualizar Stock del Producto
            BigDecimal stockPrevio = (producto.getStockActual() != null ? producto.getStockActual() : BigDecimal.ZERO);
            producto.setStockActual(stockPrevio.add(cantidadTotal));
            productoRepository.save(producto);

            // 4. Registrar en el Kardex (Movimiento Inventario) con protección de longitud VARCHAR(255)
            MovimientoInventario mov = new MovimientoInventario();
            mov.setProducto(producto);
            mov.setTipoMovimiento("ENTRADA");
            mov.setCantidad(cantidadTotal);
            String motivoCompra = "Compra a proveedor: " + proveedor.getRazonSocial() + (comprobanteTrim != null ? " (" + comprobanteTrim + ")" : "");
            if (motivoCompra.length() > 255) {
                motivoCompra = motivoCompra.substring(0, 255);
            }
            mov.setMotivo(motivoCompra);
            mov.setUsuarioResponsable(usuarioActual);
            movimientoInventarioRepository.save(mov);
        }

        if (totalCompra.compareTo(BigDecimal.ZERO) <= 0) {
            throw new RuntimeException("El importe total de la compra debe ser mayor a cero.");
        }

        // Finalizar y guardar
        compra.setTotal(totalCompra);
        Compra cabeceraGuardada = compraRepository.save(compra);

        for (CompraDetalle det : detallesGuardados) {
            det.setCompra(cabeceraGuardada);
            compraDetalleRepository.save(det);
        }

        return mapToDTO(cabeceraGuardada, detallesGuardados);
    }

    @Transactional(readOnly = true)
    public List<CompraDTO> listarTodas() {
        Long idBodega = tenantService.getCurrentBodegaId();
        // Carga protegida con límite de 150 registros para evitar agotamiento de memoria en Render
        List<Compra> compras = compraRepository.findTop150ByBodega_IdBodegaOrderByFechaCompraDesc(idBodega);
        if (compras.isEmpty()) {
            return java.util.Collections.emptyList();
        }

        // Eliminación de consulta N+1: Cargar todos los detalles en una única consulta batch IN
        List<Long> idsCompra = compras.stream().map(Compra::getIdCompra).collect(Collectors.toList());
        List<CompraDetalle> todosLosDetalles = compraDetalleRepository.findByCompra_IdCompraIn(idsCompra);
        java.util.Map<Long, List<CompraDetalle>> detallesPorCompra = todosLosDetalles.stream()
                .collect(Collectors.groupingBy(d -> d.getCompra().getIdCompra()));

        return compras.stream().map(c -> {
            List<CompraDetalle> dets = detallesPorCompra.getOrDefault(c.getIdCompra(), java.util.Collections.emptyList());
            return mapToDTO(c, dets);
        }).collect(Collectors.toList());
    }

    private CompraDTO mapToDTO(Compra compra, List<CompraDetalle> detalles) {
        CompraDTO dto = new CompraDTO();
        dto.setIdCompra(compra.getIdCompra());
        dto.setIdProveedor(compra.getProveedor().getIdProveedor());
        dto.setRazonSocialProveedor(compra.getProveedor().getRazonSocial());
        dto.setComprobante(compra.getComprobante());
        dto.setTotal(compra.getTotal());
        dto.setFechaCompra(compra.getFechaCompra());
        dto.setUsuarioRegistro(compra.getUsuarioRegistro());

        dto.setDetalles(detalles.stream().map(d -> {
            CompraDetalleDTO detDto = new CompraDetalleDTO();
            detDto.setIdDetalleCompra(d.getIdDetalleCompra());
            detDto.setIdProducto(d.getProducto().getIdProducto());
            detDto.setNombreProducto(d.getProducto().getNombre());
            detDto.setCantidad(d.getCantidad());
            detDto.setPrecioUnitario(d.getPrecioUnitario());
            detDto.setSubtotal(d.getSubtotal());
            return detDto;
        }).collect(Collectors.toList()));

        return dto;
    }

    private String obtenerUsuarioActual() {
        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) {
            return auth.getName();
        }
        return "SISTEMA";
    }
}
