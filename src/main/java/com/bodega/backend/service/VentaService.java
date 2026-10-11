package com.bodega.backend.service;

import com.bodega.backend.dto.VentaDTO;
import com.bodega.backend.dto.VentaDetalleDTO;
import com.bodega.backend.entity.*;
import com.bodega.backend.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class VentaService {

    private final VentaRepository ventaRepository;
    private final VentaDetalleRepository ventaDetalleRepository;
    private final ProductoRepository productoRepository;
    private final MovimientoInventarioRepository movimientoInventarioRepository;

    public VentaService(VentaRepository ventaRepository,
                        VentaDetalleRepository ventaDetalleRepository,
                        ProductoRepository productoRepository,
                        MovimientoInventarioRepository movimientoInventarioRepository) {
        this.ventaRepository = ventaRepository;
        this.ventaDetalleRepository = ventaDetalleRepository;
        this.productoRepository = productoRepository;
        this.movimientoInventarioRepository = movimientoInventarioRepository;
    }

    @Transactional
    public VentaDTO registrarVenta(VentaDTO dto) {
        Venta venta = new Venta();
        venta.setClienteDocumento(dto.getClienteDocumento());
        venta.setClienteNombre(dto.getClienteNombre());
        venta.setMetodoPago(dto.getMetodoPago() != null ? dto.getMetodoPago() : "Efectivo");

        BigDecimal totalVenta = BigDecimal.ZERO;
        List<VentaDetalle> detallesGuardados = new ArrayList<>();

        for (VentaDetalleDTO detDto : dto.getDetalles()) {
            Producto producto = productoRepository.findById(detDto.getIdProducto())
                    .orElseThrow(() -> new RuntimeException("Producto no encontrado: " + detDto.getIdProducto()));

            // Validación estricta de Stock
            if (producto.getStockActual().compareTo(detDto.getCantidad()) < 0) {
                throw new RuntimeException("Stock insuficiente para: " + producto.getNombre() + 
                                           ". Tienes: " + producto.getStockActual() + " y quieres vender: " + detDto.getCantidad());
            }

            // Seguridad: El precio se extrae directamente de la base de datos
            BigDecimal precioFinal = producto.getPrecioVenta();
            BigDecimal subtotal = detDto.getCantidad().multiply(precioFinal);
            totalVenta = totalVenta.add(subtotal);

            VentaDetalle detalle = new VentaDetalle();
            detalle.setProducto(producto);
            detalle.setCantidad(detDto.getCantidad());
            detalle.setPrecioUnitario(precioFinal);
            detalle.setSubtotal(subtotal);
            detallesGuardados.add(detalle);

            // Restar Stock
            producto.setStockActual(producto.getStockActual().subtract(detDto.getCantidad()));
            productoRepository.save(producto);

            // Registrar en Kardex
            MovimientoInventario mov = new MovimientoInventario();
            mov.setProducto(producto);
            mov.setTipoMovimiento("SALIDA");
            mov.setCantidad(detDto.getCantidad());
            String nombreCliente = (dto.getClienteNombre() != null) ? dto.getClienteNombre() : "Público General";
            mov.setMotivo("Venta al cliente: " + nombreCliente);
            movimientoInventarioRepository.save(mov);
        }

        venta.setTotal(totalVenta);
        Venta cabeceraGuardada = ventaRepository.save(venta);

        for (VentaDetalle det : detallesGuardados) {
            det.setVenta(cabeceraGuardada);
            ventaDetalleRepository.save(det);
        }

        return mapToDTO(cabeceraGuardada, detallesGuardados);
    }

    private VentaDTO mapToDTO(Venta venta, List<VentaDetalle> detalles) {
        VentaDTO dto = new VentaDTO();
        dto.setIdVenta(venta.getIdVenta());
        dto.setClienteDocumento(venta.getClienteDocumento());
        dto.setClienteNombre(venta.getClienteNombre());
        dto.setMetodoPago(venta.getMetodoPago());
        dto.setTotal(venta.getTotal());
        dto.setFechaVenta(venta.getFechaVenta());

        dto.setDetalles(detalles.stream().map(d -> {
            VentaDetalleDTO detDto = new VentaDetalleDTO();
            detDto.setIdDetalleVenta(d.getIdDetalleVenta());
            detDto.setIdProducto(d.getProducto().getIdProducto());
            detDto.setNombreProducto(d.getProducto().getNombre());
            detDto.setCantidad(d.getCantidad());
            detDto.setPrecioUnitario(d.getPrecioUnitario());
            detDto.setSubtotal(d.getSubtotal());
            return detDto;
        }).collect(Collectors.toList()));

        return dto;
    }
}
