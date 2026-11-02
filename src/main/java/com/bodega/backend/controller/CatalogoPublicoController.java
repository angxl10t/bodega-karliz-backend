package com.bodega.backend.controller;

import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.entity.Promocion;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.PromocionRepository;
import com.bodega.backend.util.MarcaDetectorUtil;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/public/catalogo")
public class CatalogoPublicoController {

    private final BodegaRepository bodegaRepository;
    private final ProductoRepository productoRepository;
    private final PromocionRepository promocionRepository;

    private static final long PROMO_CACHE_TTL_MS = 60_000L;
    private final java.util.concurrent.ConcurrentHashMap<Long, CachedPromosEntry> promosCache = new java.util.concurrent.ConcurrentHashMap<>();

    private static class CachedPromosEntry {
        final List<Promocion> promociones;
        final long timestamp;
        CachedPromosEntry(List<Promocion> promociones) {
            this.promociones = promociones;
            this.timestamp = System.currentTimeMillis();
        }
        boolean isValid() {
            return System.currentTimeMillis() - timestamp < PROMO_CACHE_TTL_MS;
        }
    }

    public CatalogoPublicoController(BodegaRepository bodegaRepository,
                                    ProductoRepository productoRepository,
                                    PromocionRepository promocionRepository) {
        this.bodegaRepository = bodegaRepository;
        this.productoRepository = productoRepository;
        this.promocionRepository = promocionRepository;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> obtenerCatalogoPorParam(@RequestParam(required = false) String tienda) {
        return responderCatalogo(tienda);
    }

    @GetMapping("/{slugOrId}")
    public ResponseEntity<Map<String, Object>> obtenerCatalogoPorPath(@PathVariable String slugOrId) {
        return responderCatalogo(slugOrId);
    }

    private ResponseEntity<Map<String, Object>> responderCatalogo(String identificador) {
        Bodega bodega = resolverBodega(identificador);
        if (bodega == null) {
            Map<String, Object> err = new LinkedHashMap<>();
            err.put("error", "Bodega no encontrada");
            err.put("mensaje", "No se encontró ninguna tienda registrada con el identificador proporcionado.");
            err.put("esPro", false);
            return ResponseEntity.status(404).body(err);
        }

        String plan = bodega.getPlan() != null ? bodega.getPlan().trim().toUpperCase() : "BASICO";
        boolean esPro = "PRO".equals(plan) || "CORPORATIVO".equals(plan);

        // Validar vencimiento del plan
        if (esPro && bodega.getFechaVencimientoPlan() != null) {
            if (bodega.getFechaVencimientoPlan().isBefore(OffsetDateTime.now())) {
                esPro = false;
            }
        }

        Map<String, Object> bodegaData = new LinkedHashMap<>();
        bodegaData.put("idBodega", bodega.getIdBodega());
        bodegaData.put("nombreComercial", bodega.getNombreComercial());
        bodegaData.put("telefono", bodega.getTelefono() != null ? bodega.getTelefono().trim() : "");
        bodegaData.put("direccion", bodega.getDireccion() != null ? bodega.getDireccion() : "");
        bodegaData.put("logoUrl", bodega.getLogoUrl() != null ? bodega.getLogoUrl() : "");
        bodegaData.put("colorPrimario", bodega.getColorPrimario() != null ? bodega.getColorPrimario() : "#2563EB");
        bodegaData.put("lemaComercial", bodega.getLemaComercial() != null ? bodega.getLemaComercial() : "");
        bodegaData.put("plan", plan);
        bodegaData.put("esPro", esPro);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("bodega", bodegaData);
        response.put("esPro", esPro);

        if (!esPro) {
            response.put("mensaje", "El catálogo digital 'Mi Bodega Online' está disponible exclusivamente para tiendas con Suscripción PRO en CajaYa Cloud POS.");
            response.put("totalProductos", 0);
            response.put("categorias", List.of());
            response.put("productos", List.of());
            response.put("promociones", List.of());
            return ResponseEntity.ok(response);
        }

        // Cargar productos de la bodega
        List<Producto> productos = productoRepository.findByBodega_IdBodegaAndEstadoTrue(bodega.getIdBodega());

        // Cargar promociones activas individuales de esta bodega respetando fechas de inicio y fin (con cache en memoria de 60s)
        java.time.LocalDate hoy = java.time.LocalDate.now();
        List<Promocion> promocionesRaw;
        CachedPromosEntry cachedEntry = promosCache.get(bodega.getIdBodega());
        if (cachedEntry != null && cachedEntry.isValid()) {
            promocionesRaw = cachedEntry.promociones;
        } else {
            promocionesRaw = (promocionRepository != null
                    ? promocionRepository.findByBodega_IdBodegaAndActivoTrue(bodega.getIdBodega())
                    : java.util.Collections.<Promocion>emptyList());
            promosCache.put(bodega.getIdBodega(), new CachedPromosEntry(promocionesRaw));
        }

        List<Promocion> promocionesActivas = promocionesRaw.stream()
                .filter(pr -> {
                    if (pr.getFechaInicio() != null && hoy.isBefore(pr.getFechaInicio())) return false;
                    if (pr.getFechaFin() != null && hoy.isAfter(pr.getFechaFin())) return false;
                    return true;
                })
                .collect(Collectors.toList());

        List<Map<String, Object>> prodsDto = productos.stream().map(p -> {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("idProducto", p.getIdProducto());
            item.put("codigo", p.getCodigo());
            item.put("codigoBarras", p.getCodigoBarras() != null ? p.getCodigoBarras() : "");
            item.put("nombre", p.getNombre());
            String marcaCanon = (p.getMarca() != null && !p.getMarca().isBlank())
                    ? MarcaDetectorUtil.normalizarMarca(p.getMarca())
                    : MarcaDetectorUtil.detectarMarca(p.getNombre());
            item.put("marca", marcaCanon != null ? marcaCanon : "");
            item.put("precioVenta", p.getPrecioVenta());
            item.put("stockActual", p.getStockActual() != null ? p.getStockActual().doubleValue() : 0.0);
            String catNombre = p.getCategoria() != null ? p.getCategoria().getNombre() : "General";
            item.put("categoria", catNombre);
            item.put("imagenUrl", p.getImagenUrl() != null ? p.getImagenUrl() : "");
            boolean disponible = p.getStockActual() != null && p.getStockActual().compareTo(BigDecimal.ZERO) > 0;
            item.put("disponible", disponible);

            // Evaluar promociones aplicables a este producto con tolerancia total a variantes
            Promocion promoAplicable = null;
            for (Promocion promo : promocionesActivas) {
                if ("PRODUCTO".equalsIgnoreCase(promo.getAlcance()) && promo.getIdProductoPrincipal() != null) {
                    if (promo.getIdProductoPrincipal().equals(p.getIdProducto())) {
                        promoAplicable = promo;
                        break;
                    }
                } else if ("MARCA".equalsIgnoreCase(promo.getAlcance()) && promo.getMarcaObjetivo() != null) {
                    if (MarcaDetectorUtil.coincideMarca(promo.getMarcaObjetivo(), p.getMarca(), p.getNombre())) {
                        promoAplicable = promo;
                        break;
                    }
                } else if ("CATEGORIA".equalsIgnoreCase(promo.getAlcance()) && promo.getCategoriaObjetivo() != null) {
                    if (promo.getCategoriaObjetivo().trim().equalsIgnoreCase(catNombre.trim())) {
                        promoAplicable = promo;
                        break;
                    }
                } else if ("COMBO".equalsIgnoreCase(promo.getAlcance())) {
                    if ((promo.getIdProductoPrincipal() != null && promo.getIdProductoPrincipal().equals(p.getIdProducto())) ||
                        (promo.getIdProductoSecundario() != null && promo.getIdProductoSecundario().equals(p.getIdProducto()))) {
                        promoAplicable = promo;
                        break;
                    }
                }
            }

            if (promoAplicable != null && p.getPrecioVenta() != null) {
                BigDecimal precioOriginal = p.getPrecioVenta();
                BigDecimal precioPromo = precioOriginal;
                int descPct = 0;

                if ("PORCENTAJE".equalsIgnoreCase(promoAplicable.getTipoPromocion()) && promoAplicable.getValorDescuento() != null) {
                    BigDecimal factor = BigDecimal.ONE.subtract(
                            promoAplicable.getValorDescuento().divide(new BigDecimal("100"), 4, RoundingMode.HALF_UP)
                    );
                    precioPromo = precioOriginal.multiply(factor).setScale(2, RoundingMode.HALF_UP);
                    descPct = promoAplicable.getValorDescuento().intValue();
                } else if ("MONTO_FIJO".equalsIgnoreCase(promoAplicable.getTipoPromocion()) && promoAplicable.getValorDescuento() != null) {
                    precioPromo = precioOriginal.subtract(promoAplicable.getValorDescuento()).setScale(2, RoundingMode.HALF_UP);
                    if (precioPromo.compareTo(new BigDecimal("0.50")) < 0) {
                        precioPromo = new BigDecimal("0.50");
                    }
                    if (precioOriginal.compareTo(BigDecimal.ZERO) > 0) {
                        descPct = precioOriginal.subtract(precioPromo)
                                .multiply(new BigDecimal("100"))
                                .divide(precioOriginal, 0, RoundingMode.HALF_UP)
                                .intValue();
                    }
                } else if ("DOS_POR_UNO".equalsIgnoreCase(promoAplicable.getTipoPromocion())) {
                    precioPromo = precioOriginal.divide(new BigDecimal("2"), 2, RoundingMode.HALF_UP);
                    descPct = 50;
                } else if ("COMBO".equalsIgnoreCase(promoAplicable.getTipoPromocion()) || "COMBO_HUESO".equalsIgnoreCase(promoAplicable.getTipoPromocion())) {
                    if (promoAplicable.getValorDescuento() != null && promoAplicable.getValorDescuento().compareTo(BigDecimal.ZERO) > 0) {
                        BigDecimal factor = BigDecimal.ONE.subtract(
                                promoAplicable.getValorDescuento().divide(new BigDecimal("100"), 4, RoundingMode.HALF_UP)
                        );
                        precioPromo = precioOriginal.multiply(factor).setScale(2, RoundingMode.HALF_UP);
                        descPct = promoAplicable.getValorDescuento().intValue();
                    }
                }

                item.put("tienePromocion", true);
                item.put("precioPromocional", precioPromo);
                item.put("descuentoPorcentaje", descPct);
                item.put("badgePromocion", promoAplicable.getBadgeTexto() != null ? promoAplicable.getBadgeTexto() : "🔥 OFERTA");
                item.put("colorBadge", promoAplicable.getColorBadge() != null ? promoAplicable.getColorBadge() : "#EF4444");
                item.put("tituloPromocion", promoAplicable.getTitulo());
            } else {
                item.put("tienePromocion", false);
                item.put("precioPromocional", null);
                item.put("descuentoPorcentaje", 0);
                item.put("badgePromocion", null);
                item.put("colorBadge", null);
                item.put("tituloPromocion", null);
            }

            return item;
        }).collect(Collectors.toList());

        List<String> categorias = prodsDto.stream()
                .map(p -> (String) p.get("categoria"))
                .filter(Objects::nonNull)
                .distinct()
                .sorted()
                .collect(Collectors.toList());

        // Mapear promociones llamativas para el Hero Banner Carousel del catálogo
        List<Map<String, Object>> promosDto = promocionesActivas.stream().map(pr -> {
            Map<String, Object> pm = new LinkedHashMap<>();
            pm.put("idPromocion", pr.getIdPromocion());
            pm.put("titulo", pr.getTitulo());
            pm.put("descripcion", pr.getDescripcion() != null ? pr.getDescripcion() : "");
            pm.put("tipoPromocion", pr.getTipoPromocion());
            pm.put("alcance", pr.getAlcance());
            pm.put("valorDescuento", pr.getValorDescuento());
            pm.put("categoriaObjetivo", pr.getCategoriaObjetivo());
            pm.put("marcaObjetivo", pr.getMarcaObjetivo());
            pm.put("nombreProductoPrincipal", pr.getNombreProductoPrincipal());
            pm.put("nombreProductoSecundario", pr.getNombreProductoSecundario());
            pm.put("precioCombo", pr.getPrecioCombo());
            pm.put("badgeTexto", pr.getBadgeTexto() != null ? pr.getBadgeTexto() : "🔥 OFERTA");
            pm.put("colorBadge", pr.getColorBadge() != null ? pr.getColorBadge() : "#EF4444");
            pm.put("fechaInicio", pr.getFechaInicio() != null ? pr.getFechaInicio().toString() : null);
            pm.put("fechaFin", pr.getFechaFin() != null ? pr.getFechaFin().toString() : null);
            pm.put("esSugerenciaHueso", Boolean.TRUE.equals(pr.getEsSugerenciaHueso()));
            return pm;
        }).collect(Collectors.toList());

        List<String> marcas = prodsDto.stream()
                .map(m -> (String) m.get("marca"))
                .filter(m -> m != null && !m.isBlank())
                .distinct()
                .sorted(String.CASE_INSENSITIVE_ORDER)
                .collect(Collectors.toList());

        response.put("mensaje", null);
        response.put("totalProductos", prodsDto.size());
        response.put("totalPromociones", promosDto.size());
        response.put("promociones", promosDto);
        response.put("categorias", categorias);
        response.put("marcas", marcas);
        response.put("productos", prodsDto);

        return ResponseEntity.ok(response);
    }

    private Bodega resolverBodega(String idOrSlug) {
        if (idOrSlug == null || idOrSlug.trim().isEmpty()) {
            // Optimización anti-DoS: consulta LIMIT 1 en base de datos en lugar de cargar todas las tiendas en memoria
            return bodegaRepository.findFirstByEstadoTrueAndPlanIgnoreCaseOrderByIdBodegaAsc("PRO")
                    .or(() -> bodegaRepository.findFirstByOrderByIdBodegaAsc())
                    .orElse(null);
        }

        String raw = idOrSlug.trim();
        if (raw.matches("\\d+")) {
            Long id = Long.parseLong(raw);
            Optional<Bodega> bOpt = bodegaRepository.findByIdBodegaAndEstadoTrue(id);
            if (bOpt.isPresent()) return bOpt.get();
        }

        String targetSlug = normalizarSlug(raw);
        List<Bodega> bodegas = bodegaRepository.findByEstadoTrueOrderByNombreComercialAsc();
        for (Bodega b : bodegas) {
            String bSlug = normalizarSlug(b.getNombreComercial());
            if (bSlug.equals(targetSlug) || bSlug.replace("-", "").equals(targetSlug.replace("-", ""))) {
                return b;
            }
        }

        for (Bodega b : bodegas) {
            String bSlug = normalizarSlug(b.getNombreComercial());
            if (bSlug.contains(targetSlug) || targetSlug.contains(bSlug)) {
                return b;
            }
        }

        return null;
    }

    private String normalizarSlug(String texto) {
        if (texto == null) return "";
        return texto.toLowerCase(Locale.ROOT)
                .replaceAll("[áàäâ]", "a")
                .replaceAll("[éèëê]", "e")
                .replaceAll("[íìïî]", "i")
                .replaceAll("[óòöô]", "o")
                .replaceAll("[úùüû]", "u")
                .replaceAll("[ñ]", "n")
                .replaceAll("[^a-z0-9]", "-")
                .replaceAll("-+", "-")
                .replaceAll("^-|-$", "");
    }
}
