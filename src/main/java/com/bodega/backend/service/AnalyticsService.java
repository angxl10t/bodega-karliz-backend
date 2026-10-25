package com.bodega.backend.service;

import com.bodega.backend.dto.DashboardBiDTO;
import com.bodega.backend.dto.HorarioPicoDTO;
import com.bodega.backend.dto.ProductoEstrellaDTO;
import com.bodega.backend.dto.ProductoHuesoDTO;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.VentaDetalleRepository;
import com.bodega.backend.repository.VentaRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class AnalyticsService {

    private final VentaRepository ventaRepository;
    private final VentaDetalleRepository ventaDetalleRepository;
    private final ProductoRepository productoRepository;
    private final TenantService tenantService;

    // Caché en memoria de 120 segundos para evitar saturación de la BD y del pool de conexiones
    private static final long CACHE_TTL_SECONDS = 120;
    private final ConcurrentHashMap<String, CachedBiEntry> biCache = new ConcurrentHashMap<>();

    private static class CachedBiEntry {
        final DashboardBiDTO data;
        final Instant timestamp;

        CachedBiEntry(DashboardBiDTO data) {
            this.data = data;
            this.timestamp = Instant.now();
        }

        boolean isValid() {
            return Instant.now().minusSeconds(CACHE_TTL_SECONDS).isBefore(timestamp);
        }
    }

    public AnalyticsService(VentaRepository ventaRepository,
                            VentaDetalleRepository ventaDetalleRepository,
                            ProductoRepository productoRepository,
                            TenantService tenantService) {
        this.ventaRepository = ventaRepository;
        this.ventaDetalleRepository = ventaDetalleRepository;
        this.productoRepository = productoRepository;
        this.tenantService = tenantService;
    }

    public void invalidateCache(Long idBodega) {
        if (idBodega == null) return;
        String prefix = idBodega + "_";
        biCache.keySet().removeIf(k -> k.startsWith(prefix));
    }

    @Transactional(readOnly = true)
    public DashboardBiDTO obtenerDashboardBi(int dias) {
        if (dias <= 0) dias = 30;
        Long idBodega = tenantService.getCurrentBodegaId();

        // 1. Comprobar caché en memoria
        String cacheKey = idBodega + "_" + dias;
        CachedBiEntry cached = biCache.get(cacheKey);
        if (cached != null && cached.isValid()) {
            return cached.data;
        }

        ZoneId zonePeru = ZoneId.of("America/Lima");
        OffsetDateTime now = OffsetDateTime.now(zonePeru);
        OffsetDateTime startPeriodo = now.minusDays(dias).withHour(0).withMinute(0).withSecond(0).withNano(0);
        OffsetDateTime startHoy = now.withHour(0).withMinute(0).withSecond(0).withNano(0);
        OffsetDateTime startSemanal = now.minusDays(7).withHour(0).withMinute(0).withSecond(0).withNano(0);

        // 2. Ventas agregadas en Base de Datos (0 entidades cargadas en RAM)
        BigDecimal totalVentas = ventaRepository.sumTotalVentasByPeriodo(idBodega, startPeriodo);
        long cantidadVentasPeriodo = ventaRepository.countVentasByPeriodo(idBodega, startPeriodo);

        BigDecimal totalVentasHoy = ventaRepository.sumTotalVentasByPeriodo(idBodega, startHoy);
        long cantidadVentasHoy = ventaRepository.countVentasByPeriodo(idBodega, startHoy);

        BigDecimal totalVentasSemana = ventaRepository.sumTotalVentasByPeriodo(idBodega, startSemanal);
        long cantidadVentasSemana = ventaRepository.countVentasByPeriodo(idBodega, startSemanal);

        // 3. Costos totales del periodo calculados por el motor SQL
        BigDecimal totalCostos = ventaDetalleRepository.sumTotalCostosByPeriodo(idBodega, startPeriodo);

        // 4. Margen Bruto
        BigDecimal margenBrutoSoles = totalVentas.subtract(totalCostos);
        BigDecimal porcentajeMargenBruto = BigDecimal.ZERO;
        if (totalVentas.compareTo(BigDecimal.ZERO) > 0) {
            porcentajeMargenBruto = margenBrutoSoles.multiply(new BigDecimal("100"))
                    .divide(totalVentas, 1, RoundingMode.HALF_UP);
        }

        // 5. Tickets Promedio
        BigDecimal ticketPromedioHoy = cantidadVentasHoy > 0
                ? totalVentasHoy.divide(BigDecimal.valueOf(cantidadVentasHoy), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        BigDecimal ticketPromedioSemanal = cantidadVentasSemana > 0
                ? totalVentasSemana.divide(BigDecimal.valueOf(cantidadVentasSemana), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        BigDecimal ticketPromedioPeriodo = cantidadVentasPeriodo > 0
                ? totalVentas.divide(BigDecimal.valueOf(cantidadVentasPeriodo), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        // 6. Top 10 Productos Estrella (Ejecutado y paginado en BD)
        List<Object[]> rawEstrellas = ventaDetalleRepository.findTopEstrellasByPeriodo(
                idBodega, startPeriodo, PageRequest.of(0, 10));

        List<ProductoEstrellaDTO> topEstrellas = new ArrayList<>();
        for (Object[] row : rawEstrellas) {
            Long idProd = ((Number) row[0]).longValue();
            String nombre = (String) row[1];
            String codigo = (String) row[2];
            String cat = (String) row[3];
            String img = (String) row[4];
            BigDecimal cant = row[5] != null ? new BigDecimal(row[5].toString()) : BigDecimal.ZERO;
            BigDecimal ventas = row[6] != null ? new BigDecimal(row[6].toString()) : BigDecimal.ZERO;
            BigDecimal costo = row[7] != null ? new BigDecimal(row[7].toString()) : BigDecimal.ZERO;
            BigDecimal margen = ventas.subtract(costo);
            BigDecimal pct = BigDecimal.ZERO;
            if (ventas.compareTo(BigDecimal.ZERO) > 0) {
                pct = margen.multiply(new BigDecimal("100")).divide(ventas, 1, RoundingMode.HALF_UP);
            }

            topEstrellas.add(ProductoEstrellaDTO.builder()
                    .idProducto(idProd)
                    .nombre(nombre)
                    .codigo(codigo)
                    .categoria(cat != null ? cat : "General")
                    .imagenUrl(img)
                    .unidadesVendidas(cant.setScale(0, RoundingMode.HALF_UP))
                    .totalVentas(ventas.setScale(2, RoundingMode.HALF_UP))
                    .costoTotal(costo.setScale(2, RoundingMode.HALF_UP))
                    .margenBrutoSoles(margen.setScale(2, RoundingMode.HALF_UP))
                    .porcentajeMargen(pct)
                    .build());
        }

        // 7. Productos Hueso (Anti-join indexado en BD)
        List<Object[]> rawHuesos = productoRepository.findProductosHuesoByPeriodo(
                idBodega, startPeriodo, PageRequest.of(0, 15));

        List<ProductoHuesoDTO> topHuesos = new ArrayList<>();
        for (Object[] row : rawHuesos) {
            Long idProd = ((Number) row[0]).longValue();
            String nombre = (String) row[1];
            String codigo = (String) row[2];
            String cat = (String) row[3];
            String img = (String) row[4];
            BigDecimal stock = row[5] != null ? new BigDecimal(row[5].toString()) : BigDecimal.ZERO;
            BigDecimal costoUnit = row[6] != null ? new BigDecimal(row[6].toString()) : BigDecimal.ZERO;
            BigDecimal capitalInmov = row[7] != null ? new BigDecimal(row[7].toString()) : BigDecimal.ZERO;
            Object fechaVenc = row[8];

            String accion = "Oferta 2x1 o Liquidación";
            if (capitalInmov.compareTo(new BigDecimal("50")) > 0) {
                accion = "Armar Combo con Producto Estrella";
            } else if (fechaVenc != null) {
                accion = "Revisar Caducidad y Remate Inmediato";
            }

            topHuesos.add(ProductoHuesoDTO.builder()
                    .idProducto(idProd)
                    .nombre(nombre)
                    .codigo(codigo)
                    .categoria(cat != null ? cat : "General")
                    .imagenUrl(img)
                    .stockActual(stock)
                    .precioCosto(costoUnit.setScale(2, RoundingMode.HALF_UP))
                    .capitalInmovilizado(capitalInmov.setScale(2, RoundingMode.HALF_UP))
                    .diasSinVentas(dias)
                    .accionRecomendada(accion)
                    .build());
        }

        // Totales de Hueso y Capital Inmovilizado
        BigDecimal totalCapitalInmovilizado = BigDecimal.ZERO;
        int totalProductosHueso = 0;
        List<Object[]> capitalRaw = productoRepository.calculateCapitalInmovilizado(idBodega, startPeriodo);
        if (!capitalRaw.isEmpty() && capitalRaw.get(0) != null) {
            Object[] cr = capitalRaw.get(0);
            if (cr[0] != null) totalCapitalInmovilizado = new BigDecimal(cr[0].toString());
            if (cr[1] != null) totalProductosHueso = ((Number) cr[1]).intValue();
        }

        // 8. Mapa de Calor 24 Horas
        Map<Integer, Integer> ticketsPorHora = new HashMap<>();
        Map<Integer, BigDecimal> ventasPorHora = new HashMap<>();
        for (int h = 0; h < 24; h++) {
            ticketsPorHora.put(h, 0);
            ventasPorHora.put(h, BigDecimal.ZERO);
        }

        List<Object[]> rawHoras = ventaRepository.findDistribucionHorariaNative(idBodega, startPeriodo);
        int maxTickets = 0;
        int horaPicoIdx = 19;
        int minTicketsNoCero = Integer.MAX_VALUE;
        int horaValleIdx = 14;

        for (Object[] rh : rawHoras) {
            if (rh[0] != null) {
                int h = ((Number) rh[0]).intValue();
                int t = rh[1] != null ? ((Number) rh[1]).intValue() : 0;
                BigDecimal v = rh[2] != null ? new BigDecimal(rh[2].toString()) : BigDecimal.ZERO;

                ticketsPorHora.put(h, t);
                ventasPorHora.put(h, v);

                if (t > maxTickets) {
                    maxTickets = t;
                    horaPicoIdx = h;
                }
                if (t > 0 && t < minTicketsNoCero && h >= 7 && h <= 22) {
                    minTicketsNoCero = t;
                    horaValleIdx = h;
                }
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

        DashboardBiDTO dto = DashboardBiDTO.builder()
                .diasAnalizados(dias)
                .totalVentas(totalVentas.setScale(2, RoundingMode.HALF_UP))
                .totalCostos(totalCostos.setScale(2, RoundingMode.HALF_UP))
                .margenBrutoSoles(margenBrutoSoles.setScale(2, RoundingMode.HALF_UP))
                .porcentajeMargenBruto(porcentajeMargenBruto)
                .ticketPromedioHoy(ticketPromedioHoy)
                .ticketPromedioSemanal(ticketPromedioSemanal)
                .ticketPromedioPeriodo(ticketPromedioPeriodo)
                .cantidadVentasHoy((int) cantidadVentasHoy)
                .cantidadVentasPeriodo((int) cantidadVentasPeriodo)
                .productosEstrella(topEstrellas)
                .productosHueso(topHuesos)
                .totalCapitalInmovilizado(totalCapitalInmovilizado.setScale(2, RoundingMode.HALF_UP))
                .totalProductosHueso(totalProductosHueso)
                .distribucionHoraria(distribucionHoraria)
                .horaPicoMaxima(horaPicoMaxima)
                .horaValleMinima(horaValleMinima)
                .recomendacionTurnos(recomendacion)
                .build();

        // Almacenar en caché en memoria
        biCache.put(cacheKey, new CachedBiEntry(dto));
        return dto;
    }
}
