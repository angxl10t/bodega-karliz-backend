package com.bodega.backend.service;

import com.bodega.backend.dto.PromocionDTO;
import com.bodega.backend.dto.SugerenciaComboHuesoDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.entity.Promocion;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.PromocionRepository;
import com.bodega.backend.repository.VentaDetalleRepository;
import com.bodega.backend.util.MarcaDetectorUtil;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class PromocionService {

    private final PromocionRepository promocionRepository;
    private final ProductoRepository productoRepository;
    private final VentaDetalleRepository ventaDetalleRepository;
    private final TenantService tenantService;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private org.springframework.context.ApplicationEventPublisher eventPublisher;

    public record PromocionesActualizadasEvent(Long idBodega) {}

    private void notificarActualizacionCatalogo(Bodega bodega) {
        if (eventPublisher != null && bodega != null && bodega.getIdBodega() != null) {
            eventPublisher.publishEvent(new PromocionesActualizadasEvent(bodega.getIdBodega()));
        }
    }

    public PromocionService(PromocionRepository promocionRepository,
                            ProductoRepository productoRepository,
                            VentaDetalleRepository ventaDetalleRepository,
                            TenantService tenantService) {
        this.promocionRepository = promocionRepository;
        this.productoRepository = productoRepository;
        this.ventaDetalleRepository = ventaDetalleRepository;
        this.tenantService = tenantService;
    }

    private void validarAccesoPro(Bodega bodega) {
        if (bodega == null) {
            throw new AccessDeniedException("No se encontró la bodega asociada.");
        }
        String plan = bodega.getPlan() != null ? bodega.getPlan().trim().toUpperCase() : "BASICO";
        boolean esPro = "PRO".equals(plan) || "CORPORATIVO".equals(plan);

        if (esPro && bodega.getFechaVencimientoPlan() != null) {
            if (bodega.getFechaVencimientoPlan().isBefore(OffsetDateTime.now())) {
                esPro = false;
            }
        }

        if (!esPro) {
            throw new AccessDeniedException("La gestión de promociones, descuentos y combos estratégicos es exclusiva para tiendas con Plan Minimarket PRO activo.");
        }
    }

    @Transactional(readOnly = true)
    public List<PromocionDTO> listarPromociones() {
        Bodega bodega = tenantService.getCurrentBodega();
        validarAccesoPro(bodega);
        return promocionRepository.findByBodega_IdBodegaOrderByFechaCreacionDesc(bodega.getIdBodega())
                .stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public PromocionDTO crearPromocion(PromocionDTO dto) {
        Bodega bodega = tenantService.getCurrentBodega();
        validarAccesoPro(bodega);

        Promocion p = Promocion.builder()
                .bodega(bodega)
                .titulo(dto.getTitulo() != null ? dto.getTitulo().trim() : "Promoción Especial")
                .descripcion(dto.getDescripcion() != null ? dto.getDescripcion().trim() : "")
                .tipoPromocion(dto.getTipoPromocion() != null ? dto.getTipoPromocion().trim().toUpperCase() : "PORCENTAJE")
                .alcance(dto.getAlcance() != null ? dto.getAlcance().trim().toUpperCase() : "CATEGORIA")
                .valorDescuento(dto.getValorDescuento() != null ? dto.getValorDescuento() : BigDecimal.ZERO)
                .categoriaObjetivo(dto.getCategoriaObjetivo() != null ? dto.getCategoriaObjetivo().trim() : null)
                .marcaObjetivo(dto.getMarcaObjetivo() != null && !dto.getMarcaObjetivo().isBlank() ? MarcaDetectorUtil.normalizarMarca(dto.getMarcaObjetivo().trim()) : null)
                .idProductoPrincipal(dto.getIdProductoPrincipal())
                .nombreProductoPrincipal(dto.getNombreProductoPrincipal())
                .idProductoSecundario(dto.getIdProductoSecundario())
                .nombreProductoSecundario(dto.getNombreProductoSecundario())
                .precioCombo(dto.getPrecioCombo())
                .badgeTexto(dto.getBadgeTexto() != null ? dto.getBadgeTexto().trim() : "🔥 OFERTA")
                .colorBadge(dto.getColorBadge() != null ? dto.getColorBadge().trim() : "#EF4444")
                .fechaInicio(dto.getFechaInicio())
                .fechaFin(dto.getFechaFin())
                .activo(dto.getActivo() != null ? dto.getActivo() : true)
                .esSugerenciaHueso(dto.getEsSugerenciaHueso() != null ? dto.getEsSugerenciaHueso() : false)
                .build();

        Promocion saved = promocionRepository.save(p);
        notificarActualizacionCatalogo(bodega);
        return toDTO(saved);
    }

    @Transactional
    public PromocionDTO actualizarPromocion(Long id, PromocionDTO dto) {
        Bodega bodega = tenantService.getCurrentBodega();
        validarAccesoPro(bodega);

        Promocion p = promocionRepository.findByIdPromocionAndBodega_IdBodega(id, bodega.getIdBodega())
                .orElseThrow(() -> new NoSuchElementException("Promoción no encontrada o no pertenece a su bodega"));

        if (dto.getTitulo() != null) p.setTitulo(dto.getTitulo().trim());
        if (dto.getDescripcion() != null) p.setDescripcion(dto.getDescripcion().trim());
        if (dto.getTipoPromocion() != null) p.setTipoPromocion(dto.getTipoPromocion().trim().toUpperCase());
        if (dto.getAlcance() != null) p.setAlcance(dto.getAlcance().trim().toUpperCase());
        if (dto.getValorDescuento() != null) p.setValorDescuento(dto.getValorDescuento());
        p.setCategoriaObjetivo(dto.getCategoriaObjetivo() != null ? dto.getCategoriaObjetivo().trim() : null);
        p.setMarcaObjetivo(dto.getMarcaObjetivo() != null && !dto.getMarcaObjetivo().isBlank() ? MarcaDetectorUtil.normalizarMarca(dto.getMarcaObjetivo().trim()) : null);
        p.setIdProductoPrincipal(dto.getIdProductoPrincipal());
        p.setNombreProductoPrincipal(dto.getNombreProductoPrincipal());
        p.setIdProductoSecundario(dto.getIdProductoSecundario());
        p.setNombreProductoSecundario(dto.getNombreProductoSecundario());
        p.setPrecioCombo(dto.getPrecioCombo());
        if (dto.getBadgeTexto() != null) p.setBadgeTexto(dto.getBadgeTexto().trim());
        if (dto.getColorBadge() != null) p.setColorBadge(dto.getColorBadge().trim());
        p.setFechaInicio(dto.getFechaInicio());
        p.setFechaFin(dto.getFechaFin());
        if (dto.getActivo() != null) p.setActivo(dto.getActivo());

        Promocion saved = promocionRepository.save(p);
        notificarActualizacionCatalogo(bodega);
        return toDTO(saved);
    }

    @Transactional
    public PromocionDTO cambiarEstado(Long id, boolean activo) {
        Bodega bodega = tenantService.getCurrentBodega();
        validarAccesoPro(bodega);

        Promocion p = promocionRepository.findByIdPromocionAndBodega_IdBodega(id, bodega.getIdBodega())
                .orElseThrow(() -> new NoSuchElementException("Promoción no encontrada"));

        p.setActivo(activo);
        Promocion saved = promocionRepository.save(p);
        notificarActualizacionCatalogo(bodega);
        return toDTO(saved);
    }

    @Transactional
    public void eliminarPromocion(Long id) {
        Bodega bodega = tenantService.getCurrentBodega();
        validarAccesoPro(bodega);

        Promocion p = promocionRepository.findByIdPromocionAndBodega_IdBodega(id, bodega.getIdBodega())
                .orElseThrow(() -> new NoSuchElementException("Promoción no encontrada"));

        promocionRepository.delete(p);
        notificarActualizacionCatalogo(bodega);
    }

    @Transactional(readOnly = true)
    public List<SugerenciaComboHuesoDTO> obtenerSugerenciasCombosHueso() {
        Bodega bodega = tenantService.getCurrentBodega();
        validarAccesoPro(bodega);

        Long idBodega = bodega.getIdBodega();
        ZoneId zonePeru = ZoneId.of("America/Lima");
        OffsetDateTime start30Dias = OffsetDateTime.now(zonePeru).minusDays(30);

        // 1. Obtener los productos hueso principales (sin ventas o muy baja rotación con capital inmovilizado)
        List<Object[]> rawHuesos = productoRepository.findProductosHuesoByPeriodo(idBodega, start30Dias, PageRequest.of(0, 8));
        if (rawHuesos == null || rawHuesos.isEmpty()) {
            return Collections.emptyList();
        }
        // 2. Obtener productos estrella (los más vendidos del período)
        List<Object[]> rawEstrellas = ventaDetalleRepository.findTopEstrellasByPeriodo(idBodega, start30Dias, PageRequest.of(0, 8));
        if (rawEstrellas == null) {
            rawEstrellas = Collections.emptyList();
        }

        // Cargar catálogo activo solo si no hay productos estrella por ventas para usar como fallback
        List<Producto> productosBodega = rawEstrellas.isEmpty()
                ? productoRepository.findByBodega_IdBodegaAndEstadoTrue(idBodega)
                : Collections.emptyList();

        // Batch load de productos referenciados para evitar consultas N+1 por cada fila
        Set<Long> productIds = new HashSet<>();
        for (Object[] rowH : rawHuesos) {
            productIds.add(((Number) rowH[0]).longValue());
        }
        for (Object[] rowE : rawEstrellas) {
            productIds.add(((Number) rowE[0]).longValue());
        }
        Map<Long, Producto> productosPorId = new HashMap<>();
        if (productosBodega != null) {
            for (Producto p : productosBodega) {
                if (p.getIdProducto() != null) {
                    productosPorId.put(p.getIdProducto(), p);
                }
            }
        }
        productIds.removeAll(productosPorId.keySet());
        if (!productIds.isEmpty()) {
            for (Producto p : productoRepository.findAllById(productIds)) {
                if (p.getIdProducto() != null) {
                    productosPorId.put(p.getIdProducto(), p);
                }
            }
        }

        List<SugerenciaComboHuesoDTO> sugerencias = new ArrayList<>();

        int estrellaIdx = 0;
        for (Object[] rowH : rawHuesos) {
            Long idHueso = ((Number) rowH[0]).longValue();
            String nombreHueso = (String) rowH[1];
            String catHueso = (String) rowH[3];
            String imgHueso = (String) rowH[4];
            BigDecimal stockHueso = rowH[5] != null ? new BigDecimal(rowH[5].toString()) : BigDecimal.ZERO;
            BigDecimal costoHueso = rowH[6] != null ? new BigDecimal(rowH[6].toString()) : BigDecimal.ZERO;
            BigDecimal capInmov = rowH[7] != null ? new BigDecimal(rowH[7].toString()) : BigDecimal.ZERO;

            Producto prodHueso = productosPorId.get(idHueso);
            BigDecimal precioRegHueso = prodHueso != null && prodHueso.getPrecioVenta() != null
                    ? prodHueso.getPrecioVenta()
                    : costoHueso.multiply(new BigDecimal("1.25"));

            // Buscar un producto estrella para emparejar
            Long idEstrella = null;
            String nombreEstrella = null;
            String catEstrella = null;
            String imgEstrella = null;
            BigDecimal precioRegEstrella = null;

            if (!rawEstrellas.isEmpty()) {
                Object[] rowE = rawEstrellas.get(estrellaIdx % rawEstrellas.size());
                idEstrella = ((Number) rowE[0]).longValue();
                nombreEstrella = (String) rowE[1];
                catEstrella = (String) rowE[3];
                imgEstrella = (String) rowE[4];
                Producto prodEstrella = productosPorId.get(idEstrella);
                precioRegEstrella = prodEstrella != null && prodEstrella.getPrecioVenta() != null
                        ? prodEstrella.getPrecioVenta()
                        : new BigDecimal("4.00");
                estrellaIdx++;
            } else if (productosBodega != null) {
                // Fallback: Tomar otro producto activo de la bodega diferente al hueso
                Optional<Producto> fallback = productosBodega.stream()
                        .filter(p -> !p.getIdProducto().equals(idHueso) && p.getPrecioVenta() != null)
                        .findFirst();
                if (fallback.isPresent()) {
                    Producto f = fallback.get();
                    idEstrella = f.getIdProducto();
                    nombreEstrella = f.getNombre();
                    catEstrella = f.getCategoria() != null ? f.getCategoria().getNombre() : "General";
                    imgEstrella = f.getImagenUrl();
                    precioRegEstrella = f.getPrecioVenta();
                }
            }

            if (idEstrella != null && !idEstrella.equals(idHueso)) {
                BigDecimal precioTotalReg = precioRegHueso.add(precioRegEstrella != null ? precioRegEstrella : BigDecimal.ZERO);
                // Sugerir 15% de descuento en el combo
                BigDecimal descuentoPct = new BigDecimal("15");
                BigDecimal factor = BigDecimal.ONE.subtract(descuentoPct.divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP));
                BigDecimal precioCombo = precioTotalReg.multiply(factor).setScale(1, RoundingMode.HALF_UP);
                if (precioCombo.compareTo(costoHueso) < 0) {
                    precioCombo = costoHueso.add(precioRegEstrella != null ? precioRegEstrella : BigDecimal.ZERO);
                }
                BigDecimal ahorro = precioTotalReg.subtract(precioCombo);

                String razon = String.format(Locale.US, "Libera S/ %.2f inmovilizados combinando este producto de baja rotación (%s) con el producto de alta demanda (%s).",
                        capInmov.doubleValue(), nombreHueso, nombreEstrella);

                sugerencias.add(SugerenciaComboHuesoDTO.builder()
                        .idProductoHueso(idHueso)
                        .nombreHueso(nombreHueso)
                        .categoriaHueso(catHueso)
                        .imagenUrlHueso(imgHueso)
                        .stockHueso(stockHueso)
                        .costoHueso(costoHueso)
                        .precioRegularHueso(precioRegHueso)
                        .capitalInmovilizado(capInmov)
                        .idProductoEstrella(idEstrella)
                        .nombreEstrella(nombreEstrella)
                        .categoriaEstrella(catEstrella)
                        .imagenUrlEstrella(imgEstrella)
                        .precioRegularEstrella(precioRegEstrella)
                        .tituloSugerido("Combo Dúo: " + nombreHueso + " + " + nombreEstrella)
                        .descripcionSugerida("Lleva ambos con 15% de ahorro exclusivo en nuestro catálogo online.")
                        .precioRegularTotal(precioTotalReg)
                        .precioComboSugerido(precioCombo)
                        .ahorroCliente(ahorro)
                        .porcentajeDescuentoSugerido(descuentoPct)
                        .razonEstrategica(razon)
                        .badgeSugerido("⭐ COMBO -15%")
                        .build());
            }

            if (sugerencias.size() >= 5) break;
        }

        return sugerencias;
    }

    private PromocionDTO toDTO(Promocion p) {
        return PromocionDTO.builder()
                .idPromocion(p.getIdPromocion())
                .idBodega(p.getBodega() != null ? p.getBodega().getIdBodega() : null)
                .titulo(p.getTitulo())
                .descripcion(p.getDescripcion())
                .tipoPromocion(p.getTipoPromocion())
                .alcance(p.getAlcance())
                .valorDescuento(p.getValorDescuento())
                .categoriaObjetivo(p.getCategoriaObjetivo())
                .marcaObjetivo(p.getMarcaObjetivo())
                .idProductoPrincipal(p.getIdProductoPrincipal())
                .nombreProductoPrincipal(p.getNombreProductoPrincipal())
                .idProductoSecundario(p.getIdProductoSecundario())
                .nombreProductoSecundario(p.getNombreProductoSecundario())
                .precioCombo(p.getPrecioCombo())
                .badgeTexto(p.getBadgeTexto())
                .colorBadge(p.getColorBadge())
                .fechaInicio(p.getFechaInicio())
                .fechaFin(p.getFechaFin())
                .activo(p.getActivo())
                .esSugerenciaHueso(p.getEsSugerenciaHueso())
                .fechaCreacion(p.getFechaCreacion())
                .build();
    }
}
