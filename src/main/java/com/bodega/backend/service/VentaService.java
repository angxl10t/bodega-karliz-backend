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
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class VentaService {

    private final VentaRepository ventaRepository;
    private final VentaDetalleRepository ventaDetalleRepository;
    private final ProductoRepository productoRepository;
    private final MovimientoInventarioRepository movimientoInventarioRepository;
    private final TenantService tenantService;
    private final com.bodega.backend.repository.BodegaRepository bodegaRepository;
    private final SunatRestEmissionService sunatRestEmissionService;

    public VentaService(VentaRepository ventaRepository,
                        VentaDetalleRepository ventaDetalleRepository,
                        ProductoRepository productoRepository,
                        MovimientoInventarioRepository movimientoInventarioRepository,
                        TenantService tenantService,
                        com.bodega.backend.repository.BodegaRepository bodegaRepository,
                        SunatRestEmissionService sunatRestEmissionService) {
        this.ventaRepository = ventaRepository;
        this.ventaDetalleRepository = ventaDetalleRepository;
        this.productoRepository = productoRepository;
        this.movimientoInventarioRepository = movimientoInventarioRepository;
        this.tenantService = tenantService;
        this.bodegaRepository = bodegaRepository;
        this.sunatRestEmissionService = sunatRestEmissionService;
    }

    @Transactional
    public VentaDTO registrarVenta(VentaDTO dto) {
        Long idBodega = tenantService.getCurrentBodegaId();

        // Idempotencia: Si la transacción ya fue procesada (por reintento de red), retornar la venta existente
        if (dto.getIdempotencyKey() != null && !dto.getIdempotencyKey().isBlank()) {
            String idempKey = dto.getIdempotencyKey().trim();
            java.util.Optional<Venta> ventaExistente = ventaRepository.findByBodega_IdBodegaAndIdempotencyKey(idBodega, idempKey);
            if (ventaExistente.isPresent()) {
                Venta ve = ventaExistente.get();
                List<VentaDetalle> dets = ventaDetalleRepository.findByVenta(ve);
                return mapToDTO(ve, dets);
            }
        }

        Bodega bodega = tenantService.getCurrentBodega();
        Venta venta = new Venta();
        venta.setBodega(bodega);
        if (dto.getIdempotencyKey() != null && !dto.getIdempotencyKey().isBlank()) {
            venta.setIdempotencyKey(dto.getIdempotencyKey().trim());
        }
        String docCliente = sanitizarTextoImpresion(dto.getClienteDocumento(), 20, null);
        String nomCliente = sanitizarTextoImpresion(dto.getClienteNombre(), 150, "Público General");

        venta.setClienteDocumento(docCliente);
        venta.setClienteNombre(nomCliente);
        venta.setMetodoPago(dto.getMetodoPago() != null ? dto.getMetodoPago() : "Efectivo");

        String usuarioActual = obtenerUsuarioActual();
        venta.setUsuarioRegistro(usuarioActual);
        venta.setEstado("COMPLETADA");

        BigDecimal totalVenta = BigDecimal.ZERO;
        List<VentaDetalle> detallesGuardados = new ArrayList<>();

        // Consolidación atómica: fusionar cantidades repetidas del mismo idProducto
        Map<Long, BigDecimal> cantidadesConsolidadas = new LinkedHashMap<>();
        for (VentaDetalleDTO d : dto.getDetalles()) {
            if (d.getIdProducto() == null) {
                throw new RuntimeException("Cada ítem de la venta debe tener un producto válido asignado.");
            }
            if (d.getCantidad() == null || d.getCantidad().compareTo(BigDecimal.ZERO) <= 0) {
                throw new RuntimeException("La cantidad solicitada para cada producto en la venta debe ser mayor a cero.");
            }
            cantidadesConsolidadas.merge(d.getIdProducto(), d.getCantidad(), BigDecimal::add);
        }

        if (cantidadesConsolidadas.isEmpty()) {
            throw new RuntimeException("La venta debe contener al menos un producto con cantidad válida.");
        }

        // Prevención de Deadlock en concurrencia: ordenar siempre por idProducto ascendente
        List<Long> idsProductosOrdenados = new ArrayList<>(cantidadesConsolidadas.keySet());
        Collections.sort(idsProductosOrdenados);

        for (Long idProd : idsProductosOrdenados) {
            BigDecimal cantidadTotal = cantidadesConsolidadas.get(idProd).setScale(3, java.math.RoundingMode.HALF_UP);

            // Bloqueo pesimista exclusivo restringido al tenant actual para evitar sobreventas simultáneas
            Producto producto = productoRepository.findByIdForUpdateAndBodega(idProd, idBodega)
                    .orElseThrow(() -> new RuntimeException("Producto no encontrado en esta bodega: " + idProd));

            // Validación de Integridad de Catálogo: No vender productos dados de baja o inactivos
            if (Boolean.FALSE.equals(producto.getEstado())) {
                throw new RuntimeException("No se puede vender el producto dado de baja o inactivo: " + producto.getNombre());
            }

            // Validación estricta y segura de Stock contra la cantidad total solicitada
            BigDecimal stockDisponible = (producto.getStockActual() != null ? producto.getStockActual() : BigDecimal.ZERO);
            if (stockDisponible.compareTo(cantidadTotal) < 0) {
                throw new RuntimeException("Stock insuficiente para: " + producto.getNombre() + 
                                           ". Tienes: " + stockDisponible + " y quieres vender: " + cantidadTotal);
            }

            // Seguridad: El precio se extrae directamente de la base de datos con redondeo comercial exacto
            BigDecimal precioFinal = producto.getPrecioVenta().setScale(2, java.math.RoundingMode.HALF_UP);
            BigDecimal subtotal = cantidadTotal.multiply(precioFinal).setScale(2, java.math.RoundingMode.HALF_UP);
            totalVenta = totalVenta.add(subtotal);

            VentaDetalle detalle = new VentaDetalle();
            detalle.setProducto(producto);
            detalle.setCantidad(cantidadTotal);
            detalle.setPrecioUnitario(precioFinal);
            detalle.setSubtotal(subtotal);
            detalle.setBodega(bodega != null ? bodega : producto.getBodega());
            detallesGuardados.add(detalle);

            // Restar Stock de forma segura frente a nulos
            producto.setStockActual(stockDisponible.subtract(cantidadTotal));
            productoRepository.save(producto);

            // Registrar en Kardex con protección de longitud VARCHAR(255)
            MovimientoInventario mov = new MovimientoInventario();
            mov.setProducto(producto);
            mov.setTipoMovimiento("SALIDA");
            mov.setCantidad(cantidadTotal);
            mov.setBodega(bodega != null ? bodega : producto.getBodega());
            String motivoVenta = "Venta al cliente: " + nomCliente;
            if (motivoVenta.length() > 255) {
                motivoVenta = motivoVenta.substring(0, 255);
            }
            mov.setMotivo(motivoVenta);
            mov.setUsuarioResponsable(usuarioActual);
            movimientoInventarioRepository.save(mov);
        }

        if (totalVenta.compareTo(BigDecimal.ZERO) <= 0) {
            throw new RuntimeException("El importe total de la venta debe ser mayor a cero.");
        }

        venta.setTotal(totalVenta);

        // Auditoría de Caja: Monto recibido en efectivo y vuelto entregado
        if (dto.getMontoRecibido() != null && dto.getMontoRecibido().compareTo(BigDecimal.ZERO) > 0) {
            venta.setMontoRecibido(dto.getMontoRecibido());
            if (dto.getMontoRecibido().compareTo(totalVenta) >= 0) {
                venta.setVuelto(dto.getMontoRecibido().subtract(totalVenta));
            } else {
                venta.setVuelto(BigDecimal.ZERO);
            }
        }

        // Módulo SUNAT: Reglas de Negocio Tributarias
        String tipoSolicitado = (dto.getTipoComprobante() != null && !dto.getTipoComprobante().isBlank())
                ? dto.getTipoComprobante().trim().toUpperCase()
                : null;

        boolean sunatActivo = bodega != null && Boolean.TRUE.equals(bodega.getFacturacionSunatActiva());
        String regimen = (bodega != null && bodega.getRegimenTributario() != null) 
                ? bodega.getRegimenTributario().toUpperCase() 
                : "NUEVO_RUS";

        boolean esFactura = "FACTURA_ELECTRONICA".equals(tipoSolicitado) || "FACTURA".equals(tipoSolicitado);

        // 1. Restricción por Régimen Tributario (Nuevo RUS solo emite Boletas y Tickets)
        if (esFactura) {
            if ("NUEVO_RUS".equals(regimen)) {
                throw new RuntimeException("El régimen tributario de la bodega (Nuevo RUS) no está autorizado para emitir Facturas. Según la normativa SUNAT, solo puede emitir Boletas de Venta y Tickets.");
            }
            if (docCliente == null || !docCliente.trim().matches("^[0-9]{11}$")) {
                throw new RuntimeException("Para emitir Factura Electrónica es obligatorio proporcionar un número de RUC válido de 11 dígitos.");
            }
            if (nomCliente == null || nomCliente.trim().isBlank() 
                    || "Público General".equalsIgnoreCase(nomCliente.trim()) 
                    || "Clientes Varios".equalsIgnoreCase(nomCliente.trim())) {
                throw new RuntimeException("Para emitir Factura Electrónica es obligatorio registrar la Razón Social del cliente.");
            }
        }

        // 2. Identificación Obligatoria: Boletas de Venta >= S/ 700.00 requieren DNI obligatorio
        boolean esBoleta = !esFactura && (sunatActivo || "BOLETA_ELECTRONICA".equals(tipoSolicitado) || "BOLETA".equals(tipoSolicitado));
        if (esBoleta && totalVenta.compareTo(new BigDecimal("700.00")) >= 0) {
            if (docCliente == null || docCliente.trim().isBlank() || "00000000".equals(docCliente.trim()) || docCliente.trim().length() < 8) {
                throw new RuntimeException("Normativa SUNAT: Para Boletas de Venta con importe igual o mayor a S/ 700.00 es obligatorio identificar al cliente con su DNI (8 dígitos) o documento oficial.");
            }
        }

        // 3. Generación atómica de serie y correlativo con bloqueo pesimista
        if (sunatActivo) {
            Bodega bodegaLocked = bodegaRepository.findByIdForUpdate(idBodega).orElse(bodega);
            String tipo = esFactura ? "FACTURA_ELECTRONICA" : "BOLETA_ELECTRONICA";
            String serie = esFactura 
                    ? (bodegaLocked.getSerieFactura() != null ? bodegaLocked.getSerieFactura() : "F001")
                    : (bodegaLocked.getSerieBoleta() != null ? bodegaLocked.getSerieBoleta() : "B001");
            long correlativo = esFactura 
                    ? (bodegaLocked.getUltimoCorrelativoFactura() != null ? bodegaLocked.getUltimoCorrelativoFactura() + 1 : 1L)
                    : (bodegaLocked.getUltimoCorrelativoBoleta() != null ? bodegaLocked.getUltimoCorrelativoBoleta() + 1 : 1L);

            if (esFactura) {
                bodegaLocked.setUltimoCorrelativoFactura(correlativo);
            } else {
                bodegaLocked.setUltimoCorrelativoBoleta(correlativo);
            }
            bodegaRepository.save(bodegaLocked);

            venta.setTipoComprobante(tipo);
            venta.setSerieCorrelativo(String.format("%s-%08d", serie, correlativo));

            // Despacho telemático REST a SUNAT / OSE / PSE (tolerante a fallos de red)
            sunatRestEmissionService.despacharComprobante(venta, detallesGuardados, bodegaLocked);
        } else {
            venta.setTipoComprobante(esFactura ? "FACTURA" : "TICKET");
            venta.setEstadoSunat(null);
            venta.setSunatHash(null);
            venta.setSunatMensaje(null);
        }

        Venta cabeceraGuardada = ventaRepository.save(venta);

        for (VentaDetalle det : detallesGuardados) {
            det.setVenta(cabeceraGuardada);
            ventaDetalleRepository.save(det);
        }

        return mapToDTO(cabeceraGuardada, detallesGuardados);
    }

    @Transactional(readOnly = true)
    public List<VentaDTO> listarTodas() {
        Long idBodega = tenantService.getCurrentBodegaId();
        List<Venta> ventas;
        // Seguridad RBAC: Los cajeros solo pueden consultar transacciones del turno de hoy
        if (!esAdmin()) {
            ZoneId zonePeru = ZoneId.of("America/Lima");
            LocalDate hoyPeru = LocalDate.now(zonePeru);
            OffsetDateTime inicio = hoyPeru.atStartOfDay(zonePeru).toOffsetDateTime();
            OffsetDateTime fin = hoyPeru.atTime(java.time.LocalTime.MAX).atZone(zonePeru).toOffsetDateTime();
            ventas = ventaRepository.findByBodega_IdBodegaAndFechaVentaBetweenOrderByFechaVentaDesc(idBodega, inicio, fin);
        } else {
            // Protección contra agotamiento de memoria: límite de 150 ventas recientes para el administrador
            ventas = ventaRepository.findTop150ByBodega_IdBodegaOrderByFechaVentaDesc(idBodega);
        }

        if (ventas.isEmpty()) {
            return java.util.Collections.emptyList();
        }

        // Eliminación de consulta N+1: Cargar todos los detalles en una única consulta batch IN
        List<Long> idsVenta = ventas.stream().map(Venta::getIdVenta).collect(Collectors.toList());
        List<VentaDetalle> todosLosDetalles = ventaDetalleRepository.findByVenta_IdVentaIn(idsVenta);
        java.util.Map<Long, List<VentaDetalle>> detallesPorVenta = todosLosDetalles.stream()
                .collect(Collectors.groupingBy(d -> d.getVenta().getIdVenta()));

        return ventas.stream().map(v -> {
            List<VentaDetalle> dets = detallesPorVenta.getOrDefault(v.getIdVenta(), java.util.Collections.emptyList());
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
        LocalDate hoyPeru = LocalDate.now(zonePeru);
        if (fecha == null) {
            fecha = hoyPeru;
        }

        if (fecha.isAfter(hoyPeru)) {
            throw new RuntimeException("No se puede consultar el arqueo de caja de una fecha futura: " + fecha);
        }

        // Seguridad RBAC: Un cajero solo puede consultar el cierre de hoy, no días pasados
        if (!esAdmin() && !fecha.isEqual(hoyPeru)) {
            throw new org.springframework.security.access.AccessDeniedException(
                "No tienes permisos suficientes para consultar cierres de caja de fechas pasadas."
            );
        }

        Long idBodega = tenantService.getCurrentBodegaId();
        OffsetDateTime inicio = fecha.atStartOfDay(zonePeru).toOffsetDateTime();
        OffsetDateTime fin = fecha.atTime(java.time.LocalTime.MAX).atZone(zonePeru).toOffsetDateTime();

        List<Venta> ventas = ventaRepository.findByBodega_IdBodegaAndFechaVentaBetweenOrderByFechaVentaDesc(idBodega, inicio, fin);
        return calcularCierre(ventas, fecha.atStartOfDay(zonePeru).toOffsetDateTime());
    }

    @Transactional(readOnly = true)
    public List<CierreCajaDTO> obtenerHistorialCierres(int dias) {
        ZoneId zonePeru = ZoneId.of("America/Lima");
        LocalDate hoyPeru = LocalDate.now(zonePeru);
        int rangoDias = (dias <= 0) ? 30 : Math.min(dias, 365);
        LocalDate inicioFecha = hoyPeru.minusDays(rangoDias);

        // Seguridad RBAC: Si el usuario no es ADMIN (es cajero), solo puede ver el cierre de hoy
        if (!esAdmin()) {
            return List.of(obtenerCierreCajaHoy());
        }

        Long idBodega = tenantService.getCurrentBodegaId();
        OffsetDateTime inicio = inicioFecha.atStartOfDay(zonePeru).toOffsetDateTime();
        OffsetDateTime fin = hoyPeru.atTime(java.time.LocalTime.MAX).atZone(zonePeru).toOffsetDateTime();

        List<Venta> ventas = ventaRepository.findByBodega_IdBodegaAndFechaVentaBetweenOrderByFechaVentaDesc(idBodega, inicio, fin);

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

        BigDecimal totalVentas = BigDecimal.ZERO;
        BigDecimal totalEfectivo = BigDecimal.ZERO;
        BigDecimal totalEfectivoRecibido = BigDecimal.ZERO;
        BigDecimal totalVueltoEntregado = BigDecimal.ZERO;
        BigDecimal totalYape = BigDecimal.ZERO;
        BigDecimal totalPlin = BigDecimal.ZERO;
        BigDecimal totalTarjeta = BigDecimal.ZERO;
        int cantidadVentasValidas = 0;

        if (ventas != null) {
            for (Venta v : ventas) {
                // Seguridad contable: Excluir ventas anuladas del cálculo de ingresos y arqueo
                if ("ANULADA".equalsIgnoreCase(v.getEstado())) {
                    continue;
                }

                cantidadVentasValidas++;
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
                    BigDecimal recibido = v.getMontoRecibido() != null ? v.getMontoRecibido() : tot;
                    BigDecimal vuelto = v.getVuelto() != null ? v.getVuelto() : BigDecimal.ZERO;
                    totalEfectivoRecibido = totalEfectivoRecibido.add(recibido);
                    totalVueltoEntregado = totalVueltoEntregado.add(vuelto);
                }
            }
        }

        resumen.setCantidadVentas(cantidadVentasValidas);
        resumen.setTotalVentas(totalVentas);
        resumen.setTotalEfectivo(totalEfectivo);
        resumen.setTotalEfectivoRecibido(totalEfectivoRecibido);
        resumen.setTotalVueltoEntregado(totalVueltoEntregado);
        resumen.setTotalYape(totalYape);
        resumen.setTotalPlin(totalPlin);
        resumen.setTotalTarjeta(totalTarjeta);

        return resumen;
    }

    @Transactional
    public void anularVenta(Long idVenta) {
        anularVenta(idVenta, null);
    }

    @Transactional
    public void anularVenta(Long idVenta, String motivo) {
        // Defensa en Profundidad: El servicio valida autorización de administrador
        if (!esAdmin()) {
            throw new org.springframework.security.access.AccessDeniedException(
                "Solo un usuario con rol de Administrador puede anular ventas registradas."
            );
        }

        Long idBodega = tenantService.getCurrentBodegaId();

        // Bloqueo pesimista exclusivo restringido a la bodega activa
        Venta venta = ventaRepository.findByIdForUpdateAndBodega(idVenta, idBodega)
                .orElseThrow(() -> new RuntimeException("Venta no encontrada en su bodega con ID: " + idVenta));

        // Validación de idempotencia atómica bajo lock
        if ("ANULADA".equalsIgnoreCase(venta.getEstado())) {
            throw new RuntimeException("La venta #" + idVenta + " ya se encuentra anulada.");
        }

        List<VentaDetalle> detalles = ventaDetalleRepository.findByVenta(venta);
        String usuarioActual = obtenerUsuarioActual();
        String motivoLimpio = sanitizarTextoImpresion(
                motivo, 
                200, 
                "Anulada por usuario " + usuarioActual + " (Sin justificación especificada)"
        );

        String motivoKardex = "Anulación Venta #" + idVenta + " - Justificación: " + motivoLimpio;
        if (motivoKardex.length() > 255) {
            motivoKardex = motivoKardex.substring(0, 255);
        }

        // 1. Consolidar cantidades por producto y ordenar por idProducto ascendente
        // para prevenir interbloqueos (Deadlocks) y duplicidad de Kardex
        Map<Long, BigDecimal> cantidadesARestaurar = new LinkedHashMap<>();
        for (VentaDetalle det : detalles) {
            if (det.getProducto() != null && det.getProducto().getIdProducto() != null 
                    && det.getCantidad() != null && det.getCantidad().compareTo(BigDecimal.ZERO) > 0) {
                cantidadesARestaurar.merge(det.getProducto().getIdProducto(), det.getCantidad(), BigDecimal::add);
            }
        }

        List<Long> idsProductosOrdenados = new ArrayList<>(cantidadesARestaurar.keySet());
        Collections.sort(idsProductosOrdenados);

        // 2. Restaurar stock en inventario con bloqueo pesimista exclusivo (PESSIMISTIC_WRITE) y registrar en Kardex
        for (Long idProd : idsProductosOrdenados) {
            BigDecimal cantidadRestaurar = cantidadesARestaurar.get(idProd).setScale(3, java.math.RoundingMode.HALF_UP);
            Producto prod = productoRepository.findByIdForUpdateAndBodega(idProd, idBodega)
                    .orElseThrow(() -> new RuntimeException("Producto no encontrado para reponer stock: " + idProd));

            BigDecimal stockPrevio = (prod.getStockActual() != null ? prod.getStockActual() : BigDecimal.ZERO);
            prod.setStockActual(stockPrevio.add(cantidadRestaurar));
            productoRepository.save(prod);

            MovimientoInventario mov = new MovimientoInventario();
            mov.setProducto(prod);
            mov.setTipoMovimiento("ENTRADA");
            mov.setCantidad(cantidadRestaurar);
            mov.setMotivo(motivoKardex);
            mov.setUsuarioResponsable(usuarioActual);
            mov.setBodega(venta.getBodega() != null ? venta.getBodega() : prod.getBodega());
            movimientoInventarioRepository.save(mov);
        }

        // 3. Soft-delete contable: Marcar como ANULADA conservando el comprobante para auditoría
        venta.setEstado("ANULADA");
        venta.setFechaAnulacion(OffsetDateTime.now());
        venta.setUsuarioAnulacion(usuarioActual);
        venta.setMotivoAnulacion(motivoLimpio);

        // 4. Integridad telemática SUNAT:
        String estadoSunatActual = venta.getEstadoSunat() != null ? venta.getEstadoSunat().trim().toUpperCase() : null;
        if ("PENDIENTE_ENVIO".equals(estadoSunatActual) || "RECHAZADO".equals(estadoSunatActual) || "ERROR_ENVIO".equals(estadoSunatActual)) {
            venta.setEstadoSunat("ANULADA_LOCAL");
            venta.setSunatMensaje("Comprobante anulado localmente antes del despacho telemático a SUNAT.");
        } else if ("ACEPTADO".equals(estadoSunatActual) || "ACEPTADO_BETA".equals(estadoSunatActual)) {
            String avisoSunat = "[AVISO CONTABLE: Comprobante ACEPTADO por SUNAT (" + 
                    (venta.getSerieCorrelativo() != null ? venta.getSerieCorrelativo() : ("#" + idVenta)) + 
                    "). Para anulación tributaria ante SUNAT se requiere emitir Nota de Crédito Electrónica.]";
            String msgPrevio = venta.getSunatMensaje() != null ? venta.getSunatMensaje().trim() : "";
            if (msgPrevio.length() > 200) {
                msgPrevio = msgPrevio.substring(0, 200);
            }
            venta.setSunatMensaje(msgPrevio.isEmpty() ? avisoSunat : msgPrevio + " | " + avisoSunat);
        }

        ventaRepository.save(venta);
    }

    /**
     * Reintenta el despacho telemático a SUNAT para comprobantes pendientes o con fallo de red.
     */
    @Transactional
    public VentaDTO reintentarEnvioSunat(Long idVenta) {
        Long idBodega = tenantService.getCurrentBodegaId();
        Venta venta = ventaRepository.findByIdForUpdateAndBodega(idVenta, idBodega)
                .orElseThrow(() -> new RuntimeException("Venta no encontrada con ID: " + idVenta));

        if ("ANULADA".equalsIgnoreCase(venta.getEstado())) {
            throw new RuntimeException("No se puede reenviar a SUNAT la venta #" + idVenta + " porque ha sido anulada.");
        }

        if ("ACEPTADO".equalsIgnoreCase(venta.getEstadoSunat())) {
            throw new RuntimeException("El comprobante " + (venta.getSerieCorrelativo() != null ? venta.getSerieCorrelativo() : ("#" + idVenta)) + " ya fue aceptado previamente por SUNAT.");
        }

        if (!"BOLETA_ELECTRONICA".equalsIgnoreCase(venta.getTipoComprobante()) &&
            !"FACTURA_ELECTRONICA".equalsIgnoreCase(venta.getTipoComprobante())) {
            throw new RuntimeException("La venta #" + idVenta + " no es un comprobante electrónico SUNAT.");
        }

        List<VentaDetalle> detalles = ventaDetalleRepository.findByVenta(venta);
        Bodega bodega = bodegaRepository.findById(idBodega).orElse(venta.getBodega());

        sunatRestEmissionService.despacharComprobante(venta, detalles, bodega);
        Venta guardada = ventaRepository.save(venta);
        return mapToDTO(guardada, detalles);
    }

    private boolean esAdmin() {
        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getAuthorities() != null) {
            return auth.getAuthorities().stream()
                    .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN") || a.getAuthority().equals("ROLE_SUPERADMIN"));
        }
        return false;
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
        dto.setMontoRecibido(venta.getMontoRecibido());
        dto.setVuelto(venta.getVuelto());
        dto.setTotal(venta.getTotal());
        dto.setFechaVenta(venta.getFechaVenta());
        dto.setUsuarioRegistro(venta.getUsuarioRegistro());

        // Campos de Soft-Delete y Auditoría de Anulación
        dto.setEstado(venta.getEstado() != null ? venta.getEstado() : "COMPLETADA");
        dto.setFechaAnulacion(venta.getFechaAnulacion());
        dto.setUsuarioAnulacion(venta.getUsuarioAnulacion());
        dto.setMotivoAnulacion(venta.getMotivoAnulacion());

        // Comprobantes SUNAT
        dto.setTipoComprobante(venta.getTipoComprobante() != null ? venta.getTipoComprobante() : "TICKET");
        dto.setSerieCorrelativo(venta.getSerieCorrelativo());
        dto.setEstadoSunat(venta.getEstadoSunat());
        dto.setSunatHash(venta.getSunatHash());
        dto.setSunatMensaje(venta.getSunatMensaje());
        dto.setSunatCdrUrl(venta.getSunatCdrUrl());
        dto.setSunatPdfUrl(venta.getSunatPdfUrl());
        dto.setSunatXmlUrl(venta.getSunatXmlUrl());
        dto.setIdempotencyKey(venta.getIdempotencyKey());

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

    /**
     * Sanitiza cadenas de texto para prevenir inyecciones de comandos en impresoras
     * térmicas (ESC/POS) y neutralizar caracteres de control ASCII (0-31, 127).
     */
    private String sanitizarTextoImpresion(String texto, int maxLen, String defaultValue) {
        if (texto == null || texto.isBlank()) {
            return defaultValue;
        }
        // Elimina caracteres de control ASCII (ej. ESC \x1B, NUL \x00) y tags peligrosos
        String limpio = texto.replaceAll("[\\p{Cntrl}]", " ")
                             .replaceAll("[<>]", "")
                             .replaceAll("\\s+", " ")
                             .trim();
        if (limpio.isBlank()) {
            return defaultValue;
        }
        return (limpio.length() > maxLen) ? limpio.substring(0, maxLen) : limpio;
    }
}
