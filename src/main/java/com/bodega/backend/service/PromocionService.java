package com.bodega.backend.service;

import com.bodega.backend.dto.PromocionDTO;
import com.bodega.backend.dto.SugerenciaComboHuesoDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.entity.Promocion;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.PromocionRepository;
import com.bodega.backend.repository.VentaDetalleRepository;
import com.bodega.backend.util.CategoriaAfinidadUtil;
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

        // 1. Obtener productos hueso (estancados / baja rotación con capital inmovilizado)
        List<Object[]> rawHuesos = productoRepository.findProductosHuesoByPeriodo(idBodega, start30Dias, PageRequest.of(0, 10));
        if (rawHuesos == null) {
            rawHuesos = Collections.emptyList();
        }

        // 2. Obtener productos estrella (los más vendidos del período)
        List<Object[]> rawEstrellas = ventaDetalleRepository.findTopEstrellasByPeriodo(idBodega, start30Dias, PageRequest.of(0, 10));
        if (rawEstrellas == null) {
            rawEstrellas = Collections.emptyList();
        }

        // Fallback de productos activos si faltan datos en los reportes
        List<Producto> productosBodega = (rawHuesos.isEmpty() || rawEstrellas.isEmpty())
                ? productoRepository.findByBodega_IdBodegaAndEstadoTrue(idBodega)
                : Collections.emptyList();

        // Batch load de entidades Producto para precios de venta oficiales y datos completos
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

        // Estructuras intermedias para evaluación de afinidad
        List<ItemInventario> listaHuesos = new ArrayList<>();
        for (Object[] rowH : rawHuesos) {
            Long id = ((Number) rowH[0]).longValue();
            String nombre = (String) rowH[1];
            String cat = (String) rowH[3];
            String img = (String) rowH[4];
            BigDecimal stock = rowH[5] != null ? new BigDecimal(rowH[5].toString()) : BigDecimal.ZERO;
            BigDecimal costo = rowH[6] != null ? new BigDecimal(rowH[6].toString()) : BigDecimal.ZERO;
            BigDecimal capInmov = rowH[7] != null ? new BigDecimal(rowH[7].toString()) : BigDecimal.ZERO;

            Producto prod = productosPorId.get(id);
            BigDecimal precioReg = prod != null && prod.getPrecioVenta() != null
                    ? prod.getPrecioVenta()
                    : costo.multiply(new BigDecimal("1.25"));

            String familia = CategoriaAfinidadUtil.detectarFamilia(cat, nombre);
            listaHuesos.add(new ItemInventario(id, nombre, cat, img, stock, costo, precioReg, capInmov, familia));
        }

        List<ItemInventario> listaEstrellas = new ArrayList<>();
        for (Object[] rowE : rawEstrellas) {
            Long id = ((Number) rowE[0]).longValue();
            String nombre = (String) rowE[1];
            String cat = (String) rowE[3];
            String img = (String) rowE[4];
            Producto prod = productosPorId.get(id);
            BigDecimal precioReg = prod != null && prod.getPrecioVenta() != null
                    ? prod.getPrecioVenta()
                    : new BigDecimal("4.00");
            BigDecimal costo = prod != null && prod.getPrecioCosto() != null
                    ? prod.getPrecioCosto()
                    : precioReg.multiply(new BigDecimal("0.75"));

            String familia = CategoriaAfinidadUtil.detectarFamilia(cat, nombre);
            listaEstrellas.add(new ItemInventario(id, nombre, cat, img, BigDecimal.valueOf(50), costo, precioReg, BigDecimal.ZERO, familia));
        }

        // Si no hay estrellas registradas en ventas pero sí productos en tienda, alimentar candidatos estrella
        if (listaEstrellas.isEmpty() && productosBodega != null && !productosBodega.isEmpty()) {
            Set<Long> huesosIds = listaHuesos.stream().map(h -> h.id).collect(Collectors.toSet());
            for (Producto p : productosBodega) {
                if (!huesosIds.contains(p.getIdProducto()) && p.getPrecioVenta() != null) {
                    String cat = p.getCategoria() != null ? p.getCategoria().getNombre() : "General";
                    String fam = CategoriaAfinidadUtil.detectarFamilia(cat, p.getNombre());
                    BigDecimal costo = p.getPrecioCosto() != null ? p.getPrecioCosto() : p.getPrecioVenta().multiply(new BigDecimal("0.75"));
                    listaEstrellas.add(new ItemInventario(p.getIdProducto(), p.getNombre(), cat, p.getImagenUrl(),
                            p.getStockActual() != null ? p.getStockActual() : BigDecimal.TEN,
                            costo, p.getPrecioVenta(), BigDecimal.ZERO, fam));
                }
            }
        }

        List<SugerenciaComboHuesoDTO> sugerencias = new ArrayList<>();
        Set<String> paresProcesados = new HashSet<>();

        // =====================================================================
        // SECCIÓN 1: HUESO_ESTRELLA (Tractor Afín / Desestancamiento Inteligente)
        // Regla de Negocio: Margen del producto estrella 100% protegido.
        // El descuento se aplica exclusivamente al producto estancado (Hueso).
        // =====================================================================
        for (ItemInventario hueso : listaHuesos) {
            ItemInventario mejorEstrella = null;
            int mejorAfinidad = 0;

            for (ItemInventario estrella : listaEstrellas) {
                if (estrella.id.equals(hueso.id)) continue;
                int afinidad = CategoriaAfinidadUtil.evaluarAfinidad(hueso.familia, estrella.familia);
                // Debe cumplir afinidad mínima de 70 (incompatibles como Cerveza + Comida Perro dan 0)
                if (afinidad >= 70 && afinidad > mejorAfinidad) {
                    mejorAfinidad = afinidad;
                    mejorEstrella = estrella;
                }
            }

            if (mejorEstrella != null) {
                String clavePar = Math.min(hueso.id, mejorEstrella.id) + "-" + Math.max(hueso.id, mejorEstrella.id);
                paresProcesados.add(clavePar);

                BigDecimal precioRegEstrella = mejorEstrella.precioRegular;
                BigDecimal precioRegHueso = hueso.precioRegular;
                BigDecimal totalReg = precioRegEstrella.add(precioRegHueso);

                // Descuento del 25% al producto hueso para mover stock, respetando piso de costo + 5%
                BigDecimal precioHuesoRebajado = precioRegHueso.multiply(new BigDecimal("0.75")).setScale(2, RoundingMode.HALF_UP);
                BigDecimal pisoCostoHueso = hueso.costo.multiply(new BigDecimal("1.05")).setScale(2, RoundingMode.HALF_UP);
                if (precioHuesoRebajado.compareTo(pisoCostoHueso) < 0) {
                    precioHuesoRebajado = pisoCostoHueso;
                }

                // El precio final combo = precio estrella intacto + precio hueso rebajado
                BigDecimal precioCombo = precioRegEstrella.add(precioHuesoRebajado).setScale(1, RoundingMode.HALF_UP);
                if (precioCombo.compareTo(totalReg) >= 0) {
                    precioCombo = totalReg.multiply(new BigDecimal("0.90")).setScale(1, RoundingMode.HALF_UP);
                }
                BigDecimal ahorro = totalReg.subtract(precioCombo);
                BigDecimal pctDescuento = ahorro.divide(totalReg, 4, RoundingMode.HALF_UP).multiply(BigDecimal.valueOf(100)).setScale(0, RoundingMode.HALF_UP);

                String etiquetaAfinidad = CategoriaAfinidadUtil.obtenerEtiquetaAfinidad(hueso.familia, mejorEstrella.familia);
                String razon = String.format(Locale.US, "Libera S/ %.2f inmovilizados combinando este producto de baja rotación (%s) con el producto de alta demanda (%s).",
                        hueso.capitalInmovilizado.doubleValue(), hueso.nombre, mejorEstrella.nombre);

                String impacto = String.format(Locale.US, "Margen de %s (estrella) protegido al 100%%. Descuento aplicado únicamente a %s para recuperar capital sin pérdidas.",
                        mejorEstrella.nombre, hueso.nombre);

                sugerencias.add(SugerenciaComboHuesoDTO.builder()
                        .idProductoHueso(hueso.id)
                        .nombreHueso(hueso.nombre)
                        .categoriaHueso(hueso.categoria)
                        .imagenUrlHueso(hueso.imagenUrl)
                        .stockHueso(hueso.stock)
                        .costoHueso(hueso.costo)
                        .precioRegularHueso(precioRegHueso)
                        .capitalInmovilizado(hueso.capitalInmovilizado)
                        .idProductoEstrella(mejorEstrella.id)
                        .nombreEstrella(mejorEstrella.nombre)
                        .categoriaEstrella(mejorEstrella.categoria)
                        .imagenUrlEstrella(mejorEstrella.imagenUrl)
                        .precioRegularEstrella(precioRegEstrella)
                        .tituloSugerido("Combo Tractor: " + mejorEstrella.nombre + " + " + hueso.nombre)
                        .descripcionSugerida("Lleva tu " + mejorEstrella.nombre + " habitual y suma " + hueso.nombre + " con descuento especial.")
                        .precioRegularTotal(totalReg)
                        .precioComboSugerido(precioCombo)
                        .ahorroCliente(ahorro)
                        .porcentajeDescuentoSugerido(pctDescuento)
                        .razonEstrategica(razon)
                        .badgeSugerido("🚀 TRACTOR AFÍN -" + pctDescuento + "%")
                        .seccionSugerencia("HUESO_ESTRELLA")
                        .tipoAfinidad(etiquetaAfinidad)
                        .impactoMargen(impacto)
                        .build());
            }

            if (sugerencias.size() >= 3) break;
        }

        // =====================================================================
        // SECCIÓN 2: ALTA_ROTACION (Ocasión Bodeguera / Ticket Promedio)
        // Regla de Negocio: Ambos productos son de alta venta. Se aplica un descuento
        // moderado (6%-8%) para incrementar ticket promedio sin canibalizar margen.
        // =====================================================================
        int countEstrellasAgregadas = 0;
        for (int i = 0; i < listaEstrellas.size(); i++) {
            ItemInventario e1 = listaEstrellas.get(i);
            for (int j = i + 1; j < listaEstrellas.size(); j++) {
                ItemInventario e2 = listaEstrellas.get(j);
                if (e1.id.equals(e2.id)) continue;

                int afinidad = CategoriaAfinidadUtil.evaluarAfinidad(e1.familia, e2.familia);
                if (afinidad < 80) continue; // Solo combinaciones de consumo frecuente de alta compatibilidad

                String clavePar = Math.min(e1.id, e2.id) + "-" + Math.max(e1.id, e2.id);
                if (paresProcesados.contains(clavePar)) continue;
                paresProcesados.add(clavePar);

                BigDecimal totalReg = e1.precioRegular.add(e2.precioRegular);
                BigDecimal pctDescuento = new BigDecimal("7"); // Descuento moderado para cuidar margen
                BigDecimal precioCombo = totalReg.multiply(new BigDecimal("0.93")).setScale(1, RoundingMode.HALF_UP);
                BigDecimal ahorro = totalReg.subtract(precioCombo);

                String etiquetaAfinidad = CategoriaAfinidadUtil.obtenerEtiquetaAfinidad(e1.familia, e2.familia);
                String razon = String.format(Locale.US, "Incrementa el ticket promedio emparejando 2 productos líderes (%s y %s) con ocasión de compra compartida.",
                        e1.nombre, e2.nombre);
                String impacto = "Ambos productos de alta rotación. Descuento ligero (7%) para elevar ticket promedio sin mermar utilidad.";

                sugerencias.add(SugerenciaComboHuesoDTO.builder()
                        .idProductoHueso(e2.id) // Secundario
                        .nombreHueso(e2.nombre)
                        .categoriaHueso(e2.categoria)
                        .imagenUrlHueso(e2.imagenUrl)
                        .stockHueso(e2.stock)
                        .costoHueso(e2.costo)
                        .precioRegularHueso(e2.precioRegular)
                        .capitalInmovilizado(BigDecimal.ZERO)
                        .idProductoEstrella(e1.id) // Principal
                        .nombreEstrella(e1.nombre)
                        .categoriaEstrella(e1.categoria)
                        .imagenUrlEstrella(e1.imagenUrl)
                        .precioRegularEstrella(e1.precioRegular)
                        .tituloSugerido("Dúo Ocasión: " + e1.nombre + " + " + e2.nombre)
                        .descripcionSugerida("La combinación perfecta de consumo frecuente con un incentivo de compra compartida.")
                        .precioRegularTotal(totalReg)
                        .precioComboSugerido(precioCombo)
                        .ahorroCliente(ahorro)
                        .porcentajeDescuentoSugerido(pctDescuento)
                        .razonEstrategica(razon)
                        .badgeSugerido("⭐ DUO ESTRELLA -7%")
                        .seccionSugerencia("ALTA_ROTACION")
                        .tipoAfinidad(etiquetaAfinidad)
                        .impactoMargen(impacto)
                        .build());

                countEstrellasAgregadas++;
                if (countEstrellasAgregadas >= 2) break;
            }
            if (countEstrellasAgregadas >= 2) break;
        }

        // =====================================================================
        // SECCIÓN 3: LIQUIDACION_PAREJA (Pack Liquidación / Dúo Dormido)
        // Regla de Negocio: Combina 2 productos dormidos afines con descuento
        // agresivo (20%) para vaciar inventario sin tocar productos estrella.
        // =====================================================================
        int countLiquidacion = 0;
        for (int i = 0; i < listaHuesos.size(); i++) {
            ItemInventario h1 = listaHuesos.get(i);
            for (int j = i + 1; j < listaHuesos.size(); j++) {
                ItemInventario h2 = listaHuesos.get(j);
                if (h1.id.equals(h2.id)) continue;

                int afinidad = CategoriaAfinidadUtil.evaluarAfinidad(h1.familia, h2.familia);
                if (afinidad < 70) continue; // Misma familia o altamente afines

                String clavePar = Math.min(h1.id, h2.id) + "-" + Math.max(h1.id, h2.id);
                if (paresProcesados.contains(clavePar)) continue;
                paresProcesados.add(clavePar);

                BigDecimal totalReg = h1.precioRegular.add(h2.precioRegular);
                BigDecimal pisoCosto = h1.costo.add(h2.costo).multiply(new BigDecimal("1.05")).setScale(2, RoundingMode.HALF_UP);
                BigDecimal precioCombo = totalReg.multiply(new BigDecimal("0.80")).setScale(1, RoundingMode.HALF_UP);
                if (precioCombo.compareTo(pisoCosto) < 0) {
                    precioCombo = pisoCosto;
                }
                BigDecimal ahorro = totalReg.subtract(precioCombo);
                BigDecimal pctDescuento = ahorro.divide(totalReg, 4, RoundingMode.HALF_UP).multiply(BigDecimal.valueOf(100)).setScale(0, RoundingMode.HALF_UP);

                String etiquetaAfinidad = CategoriaAfinidadUtil.obtenerEtiquetaAfinidad(h1.familia, h2.familia);
                BigDecimal totalInmov = h1.capitalInmovilizado.add(h2.capitalInmovilizado);
                String razon = String.format(Locale.US, "Desbloquea hasta S/ %.2f de capital estancado en este pack liquidación dúo.", totalInmov.doubleValue());
                String impacto = "Liquidación conjunta de 2 productos dormidos afines para recuperar capital inmovilizado sin afectar productos estrella.";

                sugerencias.add(SugerenciaComboHuesoDTO.builder()
                        .idProductoHueso(h1.id)
                        .nombreHueso(h1.nombre)
                        .categoriaHueso(h1.categoria)
                        .imagenUrlHueso(h1.imagenUrl)
                        .stockHueso(h1.stock)
                        .costoHueso(h1.costo)
                        .precioRegularHueso(h1.precioRegular)
                        .capitalInmovilizado(h1.capitalInmovilizado)
                        .idProductoEstrella(h2.id) // Secundario
                        .nombreEstrella(h2.nombre)
                        .categoriaEstrella(h2.categoria)
                        .imagenUrlEstrella(h2.imagenUrl)
                        .precioRegularEstrella(h2.precioRegular)
                        .tituloSugerido("Pack Liquidación: " + h1.nombre + " + " + h2.nombre)
                        .descripcionSugerida("Pack promocional de liquidación especial para rotar inventario inmovilizado.")
                        .precioRegularTotal(totalReg)
                        .precioComboSugerido(precioCombo)
                        .ahorroCliente(ahorro)
                        .porcentajeDescuentoSugerido(pctDescuento)
                        .razonEstrategica(razon)
                        .badgeSugerido("🏷️ PACK CLEARANCE -" + pctDescuento + "%")
                        .seccionSugerencia("LIQUIDACION_PAREJA")
                        .tipoAfinidad(etiquetaAfinidad)
                        .impactoMargen(impacto)
                        .build());

                countLiquidacion++;
                if (countLiquidacion >= 2) break;
            }
            if (countLiquidacion >= 2) break;
        }

        return sugerencias;
    }

    private static class ItemInventario {
        final Long id;
        final String nombre;
        final String categoria;
        final String imagenUrl;
        final BigDecimal stock;
        final BigDecimal costo;
        final BigDecimal precioRegular;
        final BigDecimal capitalInmovilizado;
        final String familia;

        ItemInventario(Long id, String nombre, String categoria, String imagenUrl,
                       BigDecimal stock, BigDecimal costo, BigDecimal precioRegular,
                       BigDecimal capitalInmovilizado, String familia) {
            this.id = id;
            this.nombre = nombre;
            this.categoria = categoria;
            this.imagenUrl = imagenUrl;
            this.stock = stock;
            this.costo = costo;
            this.precioRegular = precioRegular;
            this.capitalInmovilizado = capitalInmovilizado;
            this.familia = familia;
        }
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
