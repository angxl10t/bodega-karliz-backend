package com.bodega.backend.controller;

import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.ProductoRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/public/catalogo")
public class CatalogoPublicoController {

    private final BodegaRepository bodegaRepository;
    private final ProductoRepository productoRepository;

    public CatalogoPublicoController(BodegaRepository bodegaRepository,
                                    ProductoRepository productoRepository) {
        this.bodegaRepository = bodegaRepository;
        this.productoRepository = productoRepository;
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
        bodegaData.put("telefono", bodega.getTelefono() != null ? bodega.getTelefono() : "");
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
            return ResponseEntity.ok(response);
        }

        List<Producto> productos = productoRepository.findByBodega_IdBodegaAndEstadoTrue(bodega.getIdBodega());

        List<Map<String, Object>> prodsDto = productos.stream().map(p -> {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("idProducto", p.getIdProducto());
            item.put("codigo", p.getCodigo());
            item.put("nombre", p.getNombre());
            item.put("marca", p.getMarca() != null ? p.getMarca() : "");
            item.put("precioVenta", p.getPrecioVenta());
            item.put("stockActual", p.getStockActual() != null ? p.getStockActual().doubleValue() : 0.0);
            String catNombre = p.getCategoria() != null ? p.getCategoria().getNombre() : "General";
            item.put("categoria", catNombre);
            item.put("imagenUrl", p.getImagenUrl() != null ? p.getImagenUrl() : "");
            boolean disponible = p.getStockActual() != null && p.getStockActual().compareTo(BigDecimal.ZERO) > 0;
            item.put("disponible", disponible);
            return item;
        }).collect(Collectors.toList());

        List<String> categorias = prodsDto.stream()
                .map(p -> (String) p.get("categoria"))
                .filter(Objects::nonNull)
                .distinct()
                .sorted()
                .collect(Collectors.toList());

        response.put("mensaje", null);
        response.put("totalProductos", prodsDto.size());
        response.put("categorias", categorias);
        response.put("productos", prodsDto);

        return ResponseEntity.ok(response);
    }

    private Bodega resolverBodega(String idOrSlug) {
        if (idOrSlug == null || idOrSlug.trim().isEmpty()) {
            return bodegaRepository.findFirstByOrderByIdBodegaAsc().orElse(null);
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

        return bodegaRepository.findFirstByOrderByIdBodegaAsc().orElse(null);
    }

    private String normalizarSlug(String texto) {
        if (texto == null) return "";
        return texto.toLowerCase(Locale.ROOT)
                .replaceAll("[áàäâã]", "a")
                .replaceAll("[éèëê]", "e")
                .replaceAll("[íìïî]", "i")
                .replaceAll("[óòöôõ]", "o")
                .replaceAll("[úùüû]", "u")
                .replaceAll("[ñ]", "n")
                .replaceAll("[^a-z0-9]", "-")
                .replaceAll("-+", "-")
                .replaceAll("^-|-$", "");
    }
}
