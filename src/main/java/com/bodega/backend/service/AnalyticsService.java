package com.bodega.backend.service;

import com.bodega.backend.dto.DashboardBiDTO;
import com.bodega.backend.dto.HorarioPicoDTO;
import com.bodega.backend.dto.ProductoEstrellaDTO;
import com.bodega.backend.dto.ProductoHuesoDTO;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.entity.Venta;
import com.bodega.backend.entity.VentaDetalle;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.VentaDetalleRepository;
import com.bodega.backend.repository.VentaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class AnalyticsService {

    private final VentaRepository ventaRepository;
    private final VentaDetalleRepository ventaDetalleRepository;
    private final ProductoRepository productoRepository;
    private final TenantService tenantService;

    public AnalyticsService(VentaRepository ventaRepository,
                            VentaDetalleRepository ventaDetalleRepository,
                            ProductoRepository productoRepository,
                            TenantService tenantService) {
        this.ventaRepository = ventaRepository;
        this.ventaDetalleRepository = ventaDetalleRepository;
        this.productoRepository = productoRepository;
        this.tenantService = tenantService;
    }

    @Transactional(readOnly = true)
    public DashboardBiDTO obtenerDashboardBi(int dias) {
        if (dias <= 0) dias = 30;
        Long idBodega = tenantService.getCurrentBodegaId();
        ZoneId zonePeru = ZoneId.of("America/Lima");
        OffsetDateTime now = OffsetDateTime.now(zonePeru);
        OffsetDateTime startPeriodo = now.minusDays(dias).withHour(0).withMinute(0).withSecond(0).withNano(0);
        OffsetDateTime startHoy = now.withHour(0).withMinute(0).withSecond(0).withNano(0);
        OffsetDateTime startSemanal = now.minusDays(7).withHour(0).withMinute(0).withSecond(0).withNano(0);

        // 1. Obtener ventas completadas del periodo para la bodega
        List<Venta> ventasPeriodo = ventaRepository.findByBodega_IdBodegaAndFechaVentaBetweenOrderByFechaVentaDesc(idBodega, startPeriodo, now)
                .stream()
                .filter(v -> !"ANULADA".equalsIgnoreCase(v.getEstado()))
                .collect(Collectors.toList());

        BigDecimal totalVentas = BigDecimal.ZERO;
        BigDecimal totalVentasHoy = BigDecimal.ZERO;
        BigDecimal totalVentasSemana = BigDecimal.ZERO;
        int cantidadVentasHoy = 0;
        int cantidadVentasSemana = 0;

        List<Long> idsVenta = new ArrayList<>();
        Map<Integer, Integer> ticketsPorHora = new HashMap<>();
        Map<Integer, BigDecimal> ventasPorHora = new HashMap<>();
        for (int h = 0; h < 24; h++) {
            ticketsPorHora.put(h, 0);
            ventasPorHora.put(h, BigDecimal.ZERO);
        }

        for (Venta v : ventasPeriodo) {
            BigDecimal monto = v.getTotal() != null ? v.getTotal() : BigDecimal.ZERO;
            totalVentas = totalVentas.add(monto);
            idsVenta.add(v.getIdVenta());

            if (v.getFechaVenta() != null) {
                if (!v.getFechaVenta().isBefore(startHoy)) {
                    totalVentasHoy = totalVentasHoy.add(monto);
                    cantidadVentasHoy++;
                }
                if (!v.getFechaVenta().isBefore(startSemanal)) {
                    totalVentasSemana = totalVentasSemana.add(monto);
                    cantidadVentasSemana++;
                }

                int hora = v.getFechaVenta().atZoneSameInstant(zonePeru).getHour();
                ticketsPorHora.put(hora, ticketsPorHora.get(hora) + 1);
                ventasPorHora.put(hora, ventasPorHora.get(hora).add(monto));
            }
        }

        // 2. Calcular costos reales y agregación de productos estrella a partir de los detalles
        BigDecimal totalCostos = BigDecimal.ZERO;
        Map<Long, ProductoEstrellaDTO> acumuladorEstrellas = new HashMap<>();
        Set<Long> productosVendidosIds = new HashSet<>();

        if (!idsVenta.isEmpty()) {
            List<VentaDetalle> detalles = ventaDetalleRepository.findByVenta_IdVentaIn(idsVenta);
            for (VentaDetalle d : detalles) {
                if (d.getProducto() == null) continue;
                Producto p = d.getProducto();
                Long idProd = p.getIdProducto();
                productosVendidosIds.add(idProd);

                BigDecimal cant = d.getCantidad() != null ? d.getCantidad() : BigDecimal.ZERO;
                BigDecimal subtotal = d.getSubtotal() != null ? d.getSubtotal() : BigDecimal.ZERO;

                // Determinar costo unitario: precioCosto real o fallback a 75% del precio unitario de venta
                BigDecimal costoUnit;
                if (p.getPrecioCosto() != null && p.getPrecioCosto().compareTo(BigDecimal.ZERO) > 0) {
                    costoUnit = p.getPrecioCosto();
                } else if (d.getPrecioUnitario() != null) {
                    costoUnit = d.getPrecioUnitario().multiply(new BigDecimal("0.75"));
                } else {
                    costoUnit = BigDecimal.ZERO;
                }

                BigDecimal costoDetalle = costoUnit.multiply(cant);
                totalCostos = totalCostos.add(costoDetalle);

                // Acumulador de Producto Estrella
                ProductoEstrellaDTO estrella = acumuladorEstrellas.computeIfAbsent(idProd, k -> ProductoEstrellaDTO.builder()
                        .idProducto(idProd)
                        .nombre(p.getNombre())
                        .codigo(p.getCodigo())
                        .categoria(p.getCategoria() != null ? p.getCategoria().getNombre() : "General")
                        .imagenUrl(p.getImagenUrl())
                        .unidadesVendidas(BigDecimal.ZERO)
                        .totalVentas(BigDecimal.ZERO)
                        .costoTotal(BigDecimal.ZERO)
                        .margenBrutoSoles(BigDecimal.ZERO)
                        .porcentajeMargen(BigDecimal.ZERO)
                        .build());

                estrella.setUnidadesVendidas(estrella.getUnidadesVendidas().add(cant));
                estrella.setTotalVentas(estrella.getTotalVentas().add(subtotal));
                estrella.setCostoTotal(estrella.getCostoTotal().add(costoDetalle));
            }
        }

        // Calcular margen para cada producto estrella y ordenar Top 10
        List<ProductoEstrellaDTO> rankingEstrellas = new ArrayList<>(acumuladorEstrellas.values());
        for (ProductoEstrellaDTO e : rankingEstrellas) {
            BigDecimal margenSoles = e.getTotalVentas().subtract(e.getCostoTotal());
            e.setMargenBrutoSoles(margenSoles);
            if (e.getTotalVentas().compareTo(BigDecimal.ZERO) > 0) {
                BigDecimal pct = margenSoles.multiply(new BigDecimal("100")).divide(e.getTotalVentas(), 1, RoundingMode.HALF_UP);
                e.setPorcentajeMargen(pct);
            }
        }
        rankingEstrellas.sort((a, b) -> b.getMargenBrutoSoles().compareTo(a.getMargenBrutoSoles()));
        List<ProductoEstrellaDTO> topEstrellas = rankingEstrellas.stream().limit(10).collect(Collectors.toList());

        // 3. Rentabilidad General y Tickets Promedio
        BigDecimal margenBrutoSoles = totalVentas.subtract(totalCostos);
        BigDecimal porcentajeMargenBruto = BigDecimal.ZERO;
        if (totalVentas.compareTo(BigDecimal.ZERO) > 0) {
            porcentajeMargenBruto = margenBrutoSoles.multiply(new BigDecimal("100")).divide(totalVentas, 1, RoundingMode.HALF_UP);
        }

        BigDecimal ticketPromedioHoy = cantidadVentasHoy > 0
                ? totalVentasHoy.divide(BigDecimal.valueOf(cantidadVentasHoy), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        BigDecimal ticketPromedioSemanal = cantidadVentasSemana > 0
                ? totalVentasSemana.divide(BigDecimal.valueOf(cantidadVentasSemana), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        BigDecimal ticketPromedioPeriodo = !ventasPeriodo.isEmpty()
                ? totalVentas.divide(BigDecimal.valueOf(ventasPeriodo.size()), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        // 4. Reporte de Productos Hueso (Sin rotación en el periodo y con stock inmovilizado)
        List<Producto> todosProductos = productoRepository.findByBodega_IdBodegaAndEstadoTrue(idBodega);
        List<ProductoHuesoDTO> productosHueso = new ArrayList<>();
        BigDecimal totalCapitalInmovilizado = BigDecimal.ZERO;

        for (Producto p : todosProductos) {
            BigDecimal stock = p.getStockActual() != null ? p.getStockActual() : BigDecimal.ZERO;
            if (stock.compareTo(BigDecimal.ZERO) > 0 && !productosVendidosIds.contains(p.getIdProducto())) {
                BigDecimal costo = p.getPrecioCosto() != null && p.getPrecioCosto().compareTo(BigDecimal.ZERO) > 0
                        ? p.getPrecioCosto()
                        : (p.getPrecioVenta() != null ? p.getPrecioVenta().multiply(new BigDecimal("0.75")) : BigDecimal.ZERO);

                BigDecimal capitalInmov = stock.multiply(costo);
                totalCapitalInmovilizado = totalCapitalInmovilizado.add(capitalInmov);

                String accion = "Oferta 2x1 o Liquidación";
                if (capitalInmov.compareTo(new BigDecimal("50")) > 0) {
                    accion = "Armar Combo con Producto Estrella";
                } else if (p.getFechaVencimiento() != null) {
                    accion = "Revisar Caducidad y Remate Inmediato";
                }

                productosHueso.add(ProductoHuesoDTO.builder()
                        .idProducto(p.getIdProducto())
                        .nombre(p.getNombre())
                        .codigo(p.getCodigo())
                        .categoria(p.getCategoria() != null ? p.getCategoria().getNombre() : "General")
                        .imagenUrl(p.getImagenUrl())
                        .stockActual(stock)
                        .precioCosto(costo.setScale(2, RoundingMode.HALF_UP))
                        .capitalInmovilizado(capitalInmov.setScale(2, RoundingMode.HALF_UP))
                        .diasSinVentas(dias)
                        .accionRecomendada(accion)
                        .build());
            }
        }
        productosHueso.sort((a, b) -> b.getCapitalInmovilizado().compareTo(a.getCapitalInmovilizado()));
        List<ProductoHuesoDTO> topHuesos = productosHueso.stream().limit(12).collect(Collectors.toList());

        // 5. Mapa de Calor de Horarios Pico (Distribución 24 horas)
        int maxTickets = 0;
        int horaPicoIdx = 19;
        int minTicketsNoCero = Integer.MAX_VALUE;
        int horaValleIdx = 14;

        for (int h = 0; h < 24; h++) {
            int t = ticketsPorHora.get(h);
            if (t > maxTickets) {
                maxTickets = t;
                horaPicoIdx = h;
            }
            if (t > 0 && t < minTicketsNoCero && h >= 7 && h <= 22) {
                minTicketsNoCero = t;
                horaValleIdx = h;
            }
        }

        List<HorarioPicoDTO> distribucionHoraria = new ArrayList<>();
        double umbralPico = maxTickets > 2 ? maxTickets * 0.70 : 1;

        for (int h = 0; h < 24; h++) {
            int tickets = ticketsPorHora.get(h);
            String etiqueta = String.format("%02d:00 - %02d:00", h, (h + 1) % 24);
            boolean esPico = tickets > 0 && tickets >= umbralPico;

            distribucionHoraria.add(HorarioPicoDTO.builder()
                    .hora(h)
                    .etiquetaHora(etiqueta)
                    .cantidadTickets(tickets)
                    .totalVentas(ventasPorHora.get(h).setScale(2, RoundingMode.HALF_UP))
                    .esPico(esPico)
                    .build());
        }

        String horaPicoMaxima = String.format("%02d:00 a %02d:00", horaPicoIdx, (horaPicoIdx + 1) % 24);
        String horaValleMinima = String.format("%02d:00 a %02d:00", horaValleIdx, (horaValleIdx + 1) % 24);
        String recomendacion = String.format("Horario pico detectado entre %s con %d transacciones. Se recomienda contar con apoyo en caja y verificar reposición de bebidas frías y abarrotes de alta rotación.",
                horaPicoMaxima, maxTickets);

        return DashboardBiDTO.builder()
                .diasAnalizados(dias)
                .totalVentas(totalVentas.setScale(2, RoundingMode.HALF_UP))
                .totalCostos(totalCostos.setScale(2, RoundingMode.HALF_UP))
                .margenBrutoSoles(margenBrutoSoles.setScale(2, RoundingMode.HALF_UP))
                .porcentajeMargenBruto(porcentajeMargenBruto)
                .ticketPromedioHoy(ticketPromedioHoy)
                .ticketPromedioSemanal(ticketPromedioSemanal)
                .ticketPromedioPeriodo(ticketPromedioPeriodo)
                .cantidadVentasHoy(cantidadVentasHoy)
                .cantidadVentasPeriodo(ventasPeriodo.size())
                .productosEstrella(topEstrellas)
                .productosHueso(topHuesos)
                .totalCapitalInmovilizado(totalCapitalInmovilizado.setScale(2, RoundingMode.HALF_UP))
                .totalProductosHueso(productosHueso.size())
                .distribucionHoraria(distribucionHoraria)
                .horaPicoMaxima(horaPicoMaxima)
                .horaValleMinima(horaValleMinima)
                .recomendacionTurnos(recomendacion)
                .build();
    }
}
