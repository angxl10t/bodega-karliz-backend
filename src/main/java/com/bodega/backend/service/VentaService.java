package com.bodega.backend.service;

import com.bodega.backend.dto.CierreCajaDTO;
import com.bodega.backend.dto.VentaDTO;
import com.bodega.backend.dto.VentaDetalleDTO;
import com.bodega.backend.entity.*;
import com.bodega.backend.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
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

        String usuarioActual = obtenerUsuarioActual();
        venta.setUsuarioRegistro(usuarioActual);

        BigDecimal totalVenta = BigDecimal.ZERO;
        List<VentaDetalle> detallesGuardados = new ArrayList<>();

        // Prevención de Deadlock en concurrencia: ordenar siempre por idProducto ascendente
        List<VentaDetalleDTO> detallesOrdenados = new ArrayList<>(dto.getDetalles());
        detallesOrdenados.sort(Comparator.comparing(VentaDetalleDTO::getIdProducto));

        for (VentaDetalleDTO detDto : detallesOrdenados) {
            // Bloqueo pesimista exclusivo para evitar Race Conditions / sobreventas simultáneas
            Producto producto = productoRepository.findByIdForUpdate(detDto.getIdProducto())
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
            mov.setUsuarioResponsable(usuarioActual);
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

    @Transactional(readOnly = true)
    public List<VentaDTO> listarTodas() {
        List<Venta> ventas = ventaRepository.findAllByOrderByFechaVentaDesc();
        return ventas.stream().map(v -> {
            List<VentaDetalle> dets = ventaDetalleRepository.findByVenta(v);
            return mapToDTO(v, dets);
        }).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public CierreCajaDTO obtenerCierreCajaHoy() {
        ZoneId zonePeru = ZoneId.of("America/Lima");
        LocalDate hoyPeru = LocalDate.now(zonePeru);
        return obtenerCierreCajaPorFecha(hoyPeru);
    }

    @Transactional(readOnly = true)
    public CierreCajaDTO obtenerCierreCajaPorFecha(LocalDate fecha) {
        ZoneId zonePeru = ZoneId.of("America/Lima");
        if (fecha == null) {
            fecha = LocalDate.now(zonePeru);
        }
        OffsetDateTime inicio = fecha.atStartOfDay(zonePeru).toOffsetDateTime();
        OffsetDateTime fin = fecha.plusDays(1).atStartOfDay(zonePeru).toOffsetDateTime();

        List<Venta> ventas = ventaRepository.findByFechaVentaBetweenOrderByFechaVentaDesc(inicio, fin);
        return calcularCierre(ventas, fecha.atStartOfDay(zonePeru).toOffsetDateTime());
    }

    @Transactional(readOnly = true)
    public List<CierreCajaDTO> obtenerHistorialCierres(int dias) {
        ZoneId zonePeru = ZoneId.of("America/Lima");
        LocalDate hoyPeru = LocalDate.now(zonePeru);
        int rangoDias = dias <= 0 ? 30 : dias;
        LocalDate inicioFecha = hoyPeru.minusDays(rangoDias);

        OffsetDateTime inicio = inicioFecha.atStartOfDay(zonePeru).toOffsetDateTime();
        OffsetDateTime fin = hoyPeru.plusDays(1).atStartOfDay(zonePeru).toOffsetDateTime();

        List<Venta> ventas = ventaRepository.findByFechaVentaBetweenOrderByFechaVentaDesc(inicio, fin);

        Map<LocalDate, List<Venta>> ventasPorDia = ventas.stream()
                .filter(v -> v.getFechaVenta() != null)
                .collect(Collectors.groupingBy(v -> v.getFechaVenta().atZoneSameInstant(zonePeru).toLocalDate()));

        List<CierreCajaDTO> historial = new ArrayList<>();
        List<LocalDate> fechasOrdenadas = ventasPorDia.keySet().stream()
                .sorted(Comparator.reverseOrder())
                .collect(Collectors.toList());

        for (LocalDate dia : fechasOrdenadas) {
            List<Venta> ventasDelDia = ventasPorDia.get(dia);
            historial.add(calcularCierre(ventasDelDia, dia.atStartOfDay(zonePeru).toOffsetDateTime()));
        }

        return historial;
    }

    private CierreCajaDTO calcularCierre(List<Venta> ventas, OffsetDateTime fecha) {
        CierreCajaDTO resumen = new CierreCajaDTO();
        resumen.setFecha(fecha);
        resumen.setCantidadVentas(ventas != null ? ventas.size() : 0);

        BigDecimal totalVentas = BigDecimal.ZERO;
        BigDecimal totalEfectivo = BigDecimal.ZERO;
        BigDecimal totalYape = BigDecimal.ZERO;
        BigDecimal totalPlin = BigDecimal.ZERO;
        BigDecimal totalTarjeta = BigDecimal.ZERO;

        if (ventas != null) {
            for (Venta v : ventas) {
                BigDecimal tot = v.getTotal() != null ? v.getTotal() : BigDecimal.ZERO;
                totalVentas = totalVentas.add(tot);

                String metodo = v.getMetodoPago() != null ? v.getMetodoPago().trim().toLowerCase() : "efectivo";
                if (metodo.contains("yape")) {
                    totalYape = totalYape.add(tot);
                } else if (metodo.contains("plin")) {
                    totalPlin = totalPlin.add(tot);
                } else if (metodo.contains("tarjeta") || metodo.contains("pos") || metodo.contains("card")) {
                    totalTarjeta = totalTarjeta.add(tot);
                } else {
                    totalEfectivo = totalEfectivo.add(tot);
                }
            }
        }

        resumen.setTotalVentas(totalVentas);
        resumen.setTotalEfectivo(totalEfectivo);
        resumen.setTotalYape(totalYape);
        resumen.setTotalPlin(totalPlin);
        resumen.setTotalTarjeta(totalTarjeta);

        return resumen;
    }

    @Transactional
    public void anularVenta(Long idVenta) {
        Venta venta = ventaRepository.findById(idVenta)
                .orElseThrow(() -> new RuntimeException("Venta no encontrada con ID: " + idVenta));

        List<VentaDetalle> detalles = ventaDetalleRepository.findByVenta(venta);

        String usuarioActual = obtenerUsuarioActual();

        // Restaurar stock en inventario y registrar en Kardex
        for (VentaDetalle det : detalles) {
            Producto prod = det.getProducto();
            prod.setStockActual(prod.getStockActual().add(det.getCantidad()));
            productoRepository.save(prod);

            MovimientoInventario mov = new MovimientoInventario();
            mov.setProducto(prod);
            mov.setTipoMovimiento("ENTRADA");
            mov.setCantidad(det.getCantidad());
            mov.setMotivo("Anulación de Venta #" + idVenta + " por " + usuarioActual);
            mov.setUsuarioResponsable(usuarioActual);
            movimientoInventarioRepository.save(mov);
        }

        ventaDetalleRepository.deleteAll(detalles);
        ventaRepository.delete(venta);
    }

    private String obtenerUsuarioActual() {
        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) {
            return auth.getName();
        }
        return "SISTEMA";
    }

    private VentaDTO mapToDTO(Venta venta, List<VentaDetalle> detalles) {
        VentaDTO dto = new VentaDTO();
        dto.setIdVenta(venta.getIdVenta());
        dto.setClienteDocumento(venta.getClienteDocumento());
        dto.setClienteNombre(venta.getClienteNombre());
        dto.setMetodoPago(venta.getMetodoPago());
        dto.setTotal(venta.getTotal());
        dto.setFechaVenta(venta.getFechaVenta());
        dto.setUsuarioRegistro(venta.getUsuarioRegistro());

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
