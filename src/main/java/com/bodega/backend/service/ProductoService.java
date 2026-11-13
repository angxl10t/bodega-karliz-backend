package com.bodega.backend.service;

import com.bodega.backend.dto.ProductoDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Categoria;
import com.bodega.backend.entity.MovimientoInventario;
import com.bodega.backend.entity.Presentacion;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.MovimientoInventarioRepository;
import com.bodega.backend.repository.PresentacionRepository;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.util.MarcaDetectorUtil;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.stream.Collectors;

@Service
public class ProductoService {

    private final ProductoRepository productoRepository;
    private final CategoriaRepository categoriaRepository;
    private final MovimientoInventarioRepository movimientoInventarioRepository;
    private final PresentacionRepository presentacionRepository;
    private final TenantService tenantService;
    private final AnalyticsService analyticsService;

    public ProductoService(ProductoRepository productoRepository, 
                           CategoriaRepository categoriaRepository,
                           MovimientoInventarioRepository movimientoInventarioRepository,
                           PresentacionRepository presentacionRepository,
                           TenantService tenantService) {
        this(productoRepository, categoriaRepository, movimientoInventarioRepository,
             presentacionRepository, tenantService, null);
    }

    @Autowired
    public ProductoService(ProductoRepository productoRepository, 
                           CategoriaRepository categoriaRepository,
                           MovimientoInventarioRepository movimientoInventarioRepository,
                           PresentacionRepository presentacionRepository,
                           TenantService tenantService,
                           @Autowired(required = false) AnalyticsService analyticsService) {
        this.productoRepository = productoRepository;
        this.categoriaRepository = categoriaRepository;
        this.movimientoInventarioRepository = movimientoInventarioRepository;
        this.presentacionRepository = presentacionRepository;
        this.tenantService = tenantService;
        this.analyticsService = analyticsService;
    }

    @PostConstruct
    @Transactional
    public void liberarCodigosInactivos() {
        try {
            productoRepository.limpiarCodigoBarrasDeInactivos();
            productoRepository.marcarCodigosDeInactivosComoBaja();
        } catch (Exception ignored) {}
    }

    @Transactional(readOnly = true)
    public List<ProductoDTO> listarActivos() {
        Long idBodega = tenantService.getCurrentBodegaId();
        return productoRepository.findByBodega_IdBodegaAndEstadoTrue(idBodega)
                .stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public ProductoDTO obtenerPorId(Long id) {
        Long idBodega = tenantService.getCurrentBodegaId();
        Producto producto = productoRepository.findByIdProductoAndBodega_IdBodega(id, idBodega)
                .orElseThrow(() -> new RuntimeException("Producto no encontrado con ID: " + id));
        return mapToDTO(producto);
    }

    public String getPrefixForCategoria(String nombre) {
        if (nombre == null) return "PROD";
        String clean = nombre.trim().toLowerCase();
        if (clean.contains("gaseosa") || (clean.contains("bebida") && !clean.contains("alcoh"))) {
            return "GSE";
        } else if (clean.contains("alcoh") || clean.contains("cerveza") || clean.contains("licor")) {
            return "ALC";
        } else if (clean.contains("snack") || clean.contains("piqueo")) {
            return "SNK";
        } else if (clean.contains("lácteo") || clean.contains("lacteo") || clean.contains("leche")) {
            return "LAC";
        } else if (clean.contains("embutido") || clean.contains("fiambrer")) {
            return "EMB";
        } else if (clean.contains("abarrote") || clean.contains("fideo")) {
            return "ABA";
        } else if (clean.contains("helado") || clean.contains("postre")) {
            return "HLD";
        } else if (clean.contains("golosina") || clean.contains("chocolate")) {
            return "GLS";
        } else if (clean.contains("dental") || clean.contains("personal") || clean.contains("colino")) {
            return "CPD";
        } else if (clean.contains("limpieza") || clean.contains("hogar") || clean.contains("detergente")) {
            return "LMP";
        } else if (clean.contains("cigar") || clean.contains("tabaco")) {
            return "CIG";
        } else if (clean.contains("panader") || clean.contains("desayuno") || clean.contains("pan")) {
            return "PAN";
        }
        String norm = clean.replaceAll("[^a-zA-Z0-9]", "").toUpperCase();
        if (norm.length() >= 3) {
            return norm.substring(0, 3);
        }
        return (norm + "GEN").substring(0, 3);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listarMarcasConConteo() {
        Long idBodega = tenantService.getCurrentBodegaId();
        List<Object[]> rows = productoRepository.findMarcasAndNombresActivosByBodega(idBodega);
        Map<String, Long> conteoPorMarca = new TreeMap<>(String.CASE_INSENSITIVE_ORDER);

        for (Object[] row : rows) {
            String marca = row[0] != null ? row[0].toString() : null;
            String nombre = row[1] != null ? row[1].toString() : null;
            if (marca == null || marca.isBlank()) {
                marca = MarcaDetectorUtil.detectarMarca(nombre);
            }
            if (marca != null && !marca.isBlank()) {
                marca = MarcaDetectorUtil.normalizarMarca(marca);
                conteoPorMarca.put(marca, conteoPorMarca.getOrDefault(marca, 0L) + 1L);
            }
        }

        List<Map<String, Object>> result = new ArrayList<>();
        conteoPorMarca.entrySet().stream()
                .sorted((a, b) -> {
                    int c = b.getValue().compareTo(a.getValue());
                    return (c != 0) ? c : a.getKey().compareToIgnoreCase(b.getKey());
                })
                .forEach(e -> {
                    Map<String, Object> map = new LinkedHashMap<>();
                    map.put("marca", e.getKey());
                    map.put("cantidad", e.getValue());
                    result.add(map);
                });

        return result;
    }

    @Transactional(readOnly = true)
    public String generarSiguienteCodigo(Long idCategoria) {
        Long idBodega = tenantService.getCurrentBodegaId();
        Categoria categoria = categoriaRepository.findByIdCategoriaAndBodega_IdBodega(idCategoria, idBodega)
                .orElseThrow(() -> new RuntimeException("Categoría no encontrada con ID: " + idCategoria));
        String prefix = getPrefixForCategoria(categoria.getNombre());
        List<String> codigos = productoRepository.findCodigosByBodegaAndPrefix(idBodega, prefix);
        int maxNum = 0;
        java.util.regex.Pattern pattern = java.util.regex.Pattern.compile("^" + java.util.regex.Pattern.quote(prefix) + "-(\\d+)$");
        for (String cod : codigos) {
            if (cod != null) {
                java.util.regex.Matcher m = pattern.matcher(cod.trim());
                if (m.matches()) {
                    try {
                        int num = Integer.parseInt(m.group(1));
                        if (num > maxNum) {
                            maxNum = num;
                        }
                    } catch (NumberFormatException ignored) {}
                }
            }
        }
        return String.format("%s-%04d", prefix, maxNum + 1);
    }

    @Transactional
    public ProductoDTO crear(ProductoDTO dto) {
        Long idBodega = tenantService.getCurrentBodegaId();

        // Control de Cuotas SaaS por Plan
        Bodega bodega = tenantService.getCurrentBodega();
        if (bodega != null && "BASICO".equalsIgnoreCase(bodega.getPlan())) {
            long totalActivos = productoRepository.countByBodega_IdBodegaAndEstadoTrue(idBodega);
            if (totalActivos >= 150) {
                throw new RuntimeException("Has alcanzado el límite de 150 productos activos para el Plan BÁSICO. Actualiza a Plan PRO para registrar productos ilimitados.");
            }
        }

        // Enlazar con la categoría dentro del mismo tenant
        Categoria categoria = categoriaRepository.findByIdCategoriaAndBodega_IdBodega(dto.getIdCategoria(), idBodega)
                .orElseThrow(() -> new RuntimeException("Categoría no encontrada con ID: " + dto.getIdCategoria()));

        if (Boolean.FALSE.equals(categoria.getEstado())) {
            throw new RuntimeException("No se puede registrar el producto en una categoría inactiva o dada de baja: " + categoria.getNombre());
        }

        // Generar código según categoría si no fue proporcionado
        if (dto.getCodigo() == null || dto.getCodigo().isBlank()) {
            dto.setCodigo(generarSiguienteCodigo(categoria.getIdCategoria()));
        }

        // Validaciones de reglas de negocio en el scope del tenant
        if (dto.getCodigo() != null && !dto.getCodigo().isBlank()) {
            productoRepository.findByBodega_IdBodegaAndCodigo(idBodega, dto.getCodigo().trim()).ifPresent(existente -> {
                if (Boolean.TRUE.equals(existente.getEstado())) {
                    throw new RuntimeException("Ya existe un producto activo con el código interno: " + dto.getCodigo());
                } else {
                    String base = existente.getCodigo();
                    if (base.length() > 30) base = base.substring(0, 30);
                    existente.setCodigo(base + "_BAJA_" + existente.getIdProducto());
                    productoRepository.saveAndFlush(existente);
                }
            });
        }
        if (dto.getCodigoBarras() != null && !dto.getCodigoBarras().isBlank()) {
            productoRepository.findByBodega_IdBodegaAndCodigoBarras(idBodega, dto.getCodigoBarras().trim()).ifPresent(existente -> {
                if (Boolean.TRUE.equals(existente.getEstado())) {
                    throw new RuntimeException("Ya existe un producto activo con el código de barras: " + dto.getCodigoBarras() + " (" + existente.getNombre() + ")");
                } else {
                    existente.setCodigoBarras(null);
                    productoRepository.saveAndFlush(existente);
                }
            });
        }

        if (dto.getNombre() == null || dto.getNombre().trim().isBlank()) {
            throw new RuntimeException("El nombre del producto es obligatorio.");
        }
        String nombreLimpio = dto.getNombre().trim();
        String marcaLimpia = (dto.getMarca() != null && !dto.getMarca().isBlank()) ? dto.getMarca().trim() : null;
        if (marcaLimpia == null) {
            marcaLimpia = MarcaDetectorUtil.detectarMarca(nombreLimpio);
        } else {
            marcaLimpia = MarcaDetectorUtil.normalizarMarca(marcaLimpia);
        }

        if (dto.getPrecioVenta() == null || dto.getPrecioVenta().compareTo(BigDecimal.ZERO) <= 0) {
            throw new RuntimeException("El precio de venta debe ser mayor a cero.");
        }
        if (dto.getStockActual() == null || dto.getStockActual().compareTo(BigDecimal.ZERO) < 0) {
            throw new RuntimeException("El stock inicial no puede ser negativo.");
        }
        if (dto.getStockMinimo() == null || dto.getStockMinimo().compareTo(BigDecimal.ZERO) < 0) {
            throw new RuntimeException("El stock mínimo no puede ser negativo.");
        }

        Producto producto = new Producto();
        producto.setBodega(bodega != null ? bodega : tenantService.getCurrentBodega());
        producto.setCategoria(categoria);
        producto.setCodigo(dto.getCodigo().trim());
        producto.setCodigoBarras(dto.getCodigoBarras() != null && !dto.getCodigoBarras().isBlank() ? dto.getCodigoBarras().trim() : null);
        producto.setNombre(nombreLimpio);
        producto.setMarca(marcaLimpia);
        producto.setPrecioVenta(dto.getPrecioVenta());
        producto.setStockActual(dto.getStockActual());
        producto.setStockMinimo(dto.getStockMinimo());
        
        // RN-09
        producto.setControlaVencimiento(dto.getControlaVencimiento() != null ? dto.getControlaVencimiento() : false);
        producto.setFechaVencimiento(dto.getFechaVencimiento());
        if (dto.getPrecioCosto() != null) {
            producto.setPrecioCosto(dto.getPrecioCosto());
        } else if (dto.getPrecioVenta() != null) {
            producto.setPrecioCosto(dto.getPrecioVenta().multiply(new BigDecimal("0.75")).setScale(2, java.math.RoundingMode.HALF_UP));
        }
        producto.setImagenUrl(dto.getImagenUrl() != null && !dto.getImagenUrl().isBlank() ? dto.getImagenUrl().trim() : null);

        Producto guardado = productoRepository.save(producto);

        // Auditoría Kardex: Si el producto se registra con existencias iniciales, registrar entrada
        if (guardado.getStockActual() != null && guardado.getStockActual().compareTo(BigDecimal.ZERO) > 0) {
            MovimientoInventario mov = new MovimientoInventario();
            mov.setProducto(guardado);
            mov.setTipoMovimiento("ENTRADA");
            mov.setCantidad(guardado.getStockActual());
            mov.setMotivo("Inventario Inicial de Apertura");
            mov.setUsuarioResponsable(obtenerUsuarioActual());
            mov.setBodega(guardado.getBodega());
            movimientoInventarioRepository.save(mov);
        }

        // Invalidar caché de métricas BI para reflejar nuevo producto en inventario
        if (analyticsService != null) {
            analyticsService.invalidateCache(idBodega);
        }

        return mapToDTO(guardado);
    }

    @Transactional
    public ProductoDTO actualizar(Long id, ProductoDTO dto) {
        Long idBodega = tenantService.getCurrentBodegaId();

        // Bloqueo pesimista exclusivo para serializar con ventas/compras concurrentes y evitar Lost Updates en stock
        Producto producto = productoRepository.findByIdForUpdateAndBodega(id, idBodega)
                .orElseThrow(() -> new RuntimeException("Producto no encontrado con ID: " + id));

        if (Boolean.FALSE.equals(producto.getEstado())) {
            throw new RuntimeException("No se puede editar un producto dado de baja o inactivo. Debe reactivarlo primero.");
        }

        // Snapshot de valores anteriores para auditoría en Kardex
        final String nombreAnterior = producto.getNombre();
        final String marcaAnterior = producto.getMarca();
        final Categoria categoriaAnterior = producto.getCategoria();
        final BigDecimal precioVentaAnterior = producto.getPrecioVenta();
        final BigDecimal precioCostoAnterior = producto.getPrecioCosto();
        final String codigoBarrasAnterior = producto.getCodigoBarras();
        final java.time.LocalDate fechaVencimientoAnterior = producto.getFechaVencimiento();

        if (dto.getIdCategoria() != null) {
            Categoria categoria = categoriaRepository.findByIdCategoriaAndBodega_IdBodega(dto.getIdCategoria(), idBodega)
                    .orElseThrow(() -> new RuntimeException("Categoría no encontrada con ID: " + dto.getIdCategoria()));
            if (Boolean.FALSE.equals(categoria.getEstado())) {
                throw new RuntimeException("No se puede asignar el producto a una categoría inactiva o dada de baja: " + categoria.getNombre());
            }
            if (categoriaAnterior == null || !categoriaAnterior.getIdCategoria().equals(categoria.getIdCategoria())) {
                String catAnt = categoriaAnterior != null ? categoriaAnterior.getNombre() : "Sin Categoría";
                registrarAuditoriaKardex(producto, "CAMBIO_CATEGORIA", BigDecimal.ZERO,
                        String.format("Cambio de categoría: \"%s\" -> \"%s\"", catAnt, categoria.getNombre()));
            }
            producto.setCategoria(categoria);
        }

        if (dto.getCodigo() != null && !dto.getCodigo().isBlank()) {
            productoRepository.findByBodega_IdBodegaAndCodigo(idBodega, dto.getCodigo().trim())
                    .filter(otro -> !otro.getIdProducto().equals(id))
                    .ifPresent(otro -> {
                        if (Boolean.TRUE.equals(otro.getEstado())) {
                            throw new RuntimeException("Ya existe otro producto activo con el código: " + dto.getCodigo());
                        } else {
                            String base = otro.getCodigo();
                            if (base.length() > 30) base = base.substring(0, 30);
                            otro.setCodigo(base + "_BAJA_" + otro.getIdProducto());
                            productoRepository.saveAndFlush(otro);
                        }
                    });
            producto.setCodigo(dto.getCodigo().trim());
        }
        if (dto.getNombre() != null) {
            if (dto.getNombre().trim().isBlank()) {
                throw new RuntimeException("El nombre del producto no puede estar vacío.");
            }
            String nuevoNombre = dto.getNombre().trim();
            if (nombreAnterior != null && !nombreAnterior.equals(nuevoNombre)) {
                registrarAuditoriaKardex(producto, "CAMBIO_NOMBRE", BigDecimal.ZERO,
                        String.format("Cambio de descripción/nombre: \"%s\" -> \"%s\"", nombreAnterior, nuevoNombre));
            }
            producto.setNombre(nuevoNombre);
        }
        if (dto.getMarca() != null && !dto.getMarca().trim().isBlank()) {
            String nuevaMarca = MarcaDetectorUtil.normalizarMarca(dto.getMarca().trim());
            if (marcaAnterior != null && !marcaAnterior.equalsIgnoreCase(nuevaMarca)) {
                registrarAuditoriaKardex(producto, "CAMBIO_MARCA", BigDecimal.ZERO,
                        String.format("Cambio de marca: \"%s\" -> \"%s\"", marcaAnterior, nuevaMarca));
            }
            producto.setMarca(nuevaMarca);
        } else if (producto.getMarca() == null || producto.getMarca().trim().isBlank()) {
            String auto = MarcaDetectorUtil.detectarMarca(producto.getNombre());
            if (auto != null) {
                producto.setMarca(auto);
            }
        }
        if (dto.getPrecioVenta() != null) {
            if (dto.getPrecioVenta().compareTo(BigDecimal.ZERO) <= 0) {
                throw new RuntimeException("El precio de venta debe ser mayor a cero.");
            }
            BigDecimal nuevoPrecio = dto.getPrecioVenta();
            if (precioVentaAnterior != null && precioVentaAnterior.compareTo(nuevoPrecio) != 0) {
                registrarAuditoriaKardex(producto, "CAMBIO_PRECIO", BigDecimal.ZERO,
                        String.format(java.util.Locale.US, "Cambio de precio de venta: S/ %.2f -> S/ %.2f", precioVentaAnterior, nuevoPrecio));
            }
            producto.setPrecioVenta(nuevoPrecio);
        }
        if (dto.getStockActual() != null) {
            if (dto.getStockActual().compareTo(BigDecimal.ZERO) < 0) {
                throw new RuntimeException("El stock actual no puede ser negativo.");
            }
            BigDecimal stockAnterior = producto.getStockActual() != null ? producto.getStockActual() : BigDecimal.ZERO;
            BigDecimal nuevoStock = dto.getStockActual();
            if (stockAnterior.compareTo(nuevoStock) != 0) {
                BigDecimal diff = nuevoStock.subtract(stockAnterior);
                MovimientoInventario mov = new MovimientoInventario();
                mov.setProducto(producto);
                mov.setTipoMovimiento(diff.signum() > 0 ? "ENTRADA" : "SALIDA");
                mov.setCantidad(diff.abs());
                mov.setMotivo("Ajuste manual de inventario (de " + stockAnterior + " a " + nuevoStock + ")");
                mov.setUsuarioResponsable(obtenerUsuarioActual());
                mov.setBodega(producto.getBodega());
                movimientoInventarioRepository.save(mov);
            }
            producto.setStockActual(nuevoStock);
        }
        if (dto.getStockMinimo() != null) {
            if (dto.getStockMinimo().compareTo(BigDecimal.ZERO) < 0) {
                throw new RuntimeException("El stock mínimo no puede ser negativo.");
            }
            producto.setStockMinimo(dto.getStockMinimo());
        }
        if (dto.getCodigoBarras() != null) {
            String nuevoCodigoBarras = dto.getCodigoBarras().trim();
            if (!nuevoCodigoBarras.isBlank()) {
                productoRepository.findByBodega_IdBodegaAndCodigoBarras(idBodega, nuevoCodigoBarras)
                        .filter(otro -> !otro.getIdProducto().equals(id))
                        .ifPresent(otro -> {
                            if (Boolean.TRUE.equals(otro.getEstado())) {
                                throw new RuntimeException("Ya existe otro producto activo con el código de barras: " + dto.getCodigoBarras());
                            } else {
                                otro.setCodigoBarras(null);
                                productoRepository.saveAndFlush(otro);
                            }
                        });
                if (codigoBarrasAnterior != null && !codigoBarrasAnterior.equals(nuevoCodigoBarras)) {
                    registrarAuditoriaKardex(producto, "CAMBIO_CODIGO", BigDecimal.ZERO,
                            String.format("Cambio de código de barras: %s -> %s", codigoBarrasAnterior, nuevoCodigoBarras));
                } else if (codigoBarrasAnterior == null) {
                    registrarAuditoriaKardex(producto, "CAMBIO_CODIGO", BigDecimal.ZERO,
                            String.format("Asignación de código de barras: %s", nuevoCodigoBarras));
                }
                producto.setCodigoBarras(nuevoCodigoBarras);
            } else {
                if (codigoBarrasAnterior != null && !codigoBarrasAnterior.isBlank()) {
                    registrarAuditoriaKardex(producto, "CAMBIO_CODIGO", BigDecimal.ZERO,
                            String.format("Remoción de código de barras anterior: %s", codigoBarrasAnterior));
                }
                producto.setCodigoBarras(null);
            }
        }
        if (dto.getControlaVencimiento() != null) {
            producto.setControlaVencimiento(dto.getControlaVencimiento());
        }
        if (dto.getFechaVencimiento() != null) {
            java.time.LocalDate nuevaFecha = dto.getFechaVencimiento();
            if (fechaVencimientoAnterior != null && !fechaVencimientoAnterior.equals(nuevaFecha)) {
                registrarAuditoriaKardex(producto, "CAMBIO_VENCIMIENTO", BigDecimal.ZERO,
                        String.format("Actualización de vencimiento: %s -> %s", fechaVencimientoAnterior, nuevaFecha));
            } else if (fechaVencimientoAnterior == null) {
                registrarAuditoriaKardex(producto, "CAMBIO_VENCIMIENTO", BigDecimal.ZERO,
                        String.format("Asignación de vencimiento: %s", nuevaFecha));
            }
            producto.setFechaVencimiento(nuevaFecha);
        }
        if (dto.getPrecioCosto() != null) {
            BigDecimal nuevoCosto = dto.getPrecioCosto();
            if (precioCostoAnterior != null && precioCostoAnterior.compareTo(nuevoCosto) != 0) {
                registrarAuditoriaKardex(producto, "CAMBIO_COSTO", BigDecimal.ZERO,
                        String.format(java.util.Locale.US, "Cambio de costo/compra: S/ %.2f -> S/ %.2f", precioCostoAnterior, nuevoCosto));
            } else if (precioCostoAnterior == null && nuevoCosto.compareTo(BigDecimal.ZERO) > 0) {
                registrarAuditoriaKardex(producto, "CAMBIO_COSTO", BigDecimal.ZERO,
                        String.format(java.util.Locale.US, "Registro inicial de costo: S/ %.2f", nuevoCosto));
            }
            producto.setPrecioCosto(nuevoCosto);
        }
        if (dto.getImagenUrl() != null) {
            producto.setImagenUrl(dto.getImagenUrl().trim().isBlank() ? null : dto.getImagenUrl().trim());
        }

        Producto actualizado = productoRepository.save(producto);

        // Invalidar caché de métricas BI para reflejar cambios de precio o stock
        if (analyticsService != null) {
            analyticsService.invalidateCache(idBodega);
        }

        return mapToDTO(actualizado);
    }

    private void registrarAuditoriaKardex(Producto producto, String tipoMovimiento, BigDecimal cantidad, String motivo) {
        try {
            MovimientoInventario mov = new MovimientoInventario();
            mov.setProducto(producto);
            mov.setTipoMovimiento(tipoMovimiento);
            mov.setCantidad(cantidad != null ? cantidad : BigDecimal.ZERO);
            if (motivo != null && motivo.length() > 255) {
                motivo = motivo.substring(0, 255);
            }
            mov.setMotivo(motivo);
            mov.setUsuarioResponsable(obtenerUsuarioActual());
            mov.setBodega(producto.getBodega());
            movimientoInventarioRepository.save(mov);
        } catch (Exception e) {
            org.slf4j.LoggerFactory.getLogger(ProductoService.class)
                    .warn("No se pudo registrar la auditoría en Kardex para el producto ID {}: {}", producto.getIdProducto(), e.getMessage());
        }
    }

    @Transactional
    public void desactivar(Long id) {
        Long idBodega = tenantService.getCurrentBodegaId();

        // Bloqueo pesimista para evitar desactivar un producto durante una transacción de venta/compra en vuelo
        Producto producto = productoRepository.findByIdForUpdateAndBodega(id, idBodega)
                .orElseThrow(() -> new RuntimeException("Producto no encontrado con ID: " + id));
        if (Boolean.FALSE.equals(producto.getEstado())) {
            return;
        }
        producto.setEstado(false);
        // Liberar el código de barras al dar de baja para que pueda ser reutilizado si fue dado de baja por error
        if (producto.getCodigoBarras() != null && !producto.getCodigoBarras().isBlank()) {
            producto.setCodigoBarras(null);
        }
        if (producto.getCodigo() != null && !producto.getCodigo().contains("_BAJA_")) {
            String base = producto.getCodigo();
            if (base.length() > 30) base = base.substring(0, 30);
            producto.setCodigo(base + "_BAJA_" + producto.getIdProducto());
        }
        productoRepository.save(producto);

        // Desactivación en cascada de presentaciones activas del producto
        List<Presentacion> presentaciones = presentacionRepository.findByProducto_IdProductoAndEstadoTrue(id);
        if (!presentaciones.isEmpty()) {
            for (Presentacion p : presentaciones) {
                p.setEstado(false);
            }
            presentacionRepository.saveAll(presentaciones);
        }

        // Invalidar caché de métricas BI para reflejar producto dado de baja
        if (analyticsService != null) {
            analyticsService.invalidateCache(idBodega);
        }
    }

    private String obtenerUsuarioActual() {
        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) {
            return auth.getName();
        }
        return "SISTEMA";
    }

    private ProductoDTO mapToDTO(Producto producto) {
        ProductoDTO dto = new ProductoDTO();
        dto.setIdProducto(producto.getIdProducto());
        dto.setIdCategoria(producto.getCategoria() != null ? producto.getCategoria().getIdCategoria() : null);
        dto.setNombreCategoria(producto.getCategoria() != null ? producto.getCategoria().getNombre() : "General");
        dto.setCodigo(producto.getCodigo());
        dto.setCodigoBarras(producto.getCodigoBarras());
        dto.setNombre(producto.getNombre());
        dto.setMarca(producto.getMarca());
        dto.setPrecioVenta(producto.getPrecioVenta());
        dto.setStockActual(producto.getStockActual());
        dto.setStockMinimo(producto.getStockMinimo());
        dto.setControlaVencimiento(producto.getControlaVencimiento());
        dto.setFechaVencimiento(producto.getFechaVencimiento());
        dto.setPrecioCosto(producto.getPrecioCosto() != null ? producto.getPrecioCosto() : (producto.getPrecioVenta() != null ? producto.getPrecioVenta().multiply(new BigDecimal("0.75")).setScale(2, java.math.RoundingMode.HALF_UP) : null));
        dto.setImagenUrl(producto.getImagenUrl());
        dto.setEstado(producto.getEstado());
        return dto;
    }

    @Transactional(readOnly = true)
    public byte[] exportarCsv() {
        Long idBodega = tenantService.getCurrentBodegaId();
        List<Producto> productos = productoRepository.findByBodega_IdBodegaAndEstadoTrue(idBodega);

        StringBuilder sb = new StringBuilder();
        sb.append("Codigo,CodigoBarras,Nombre,Categoria,Marca,PrecioVenta,StockActual,StockMinimo,Estado\r\n");

        for (Producto p : productos) {
            sb.append(escapeCsv(p.getCodigo())).append(",")
              .append(escapeCsv(p.getCodigoBarras())).append(",")
              .append(escapeCsv(p.getNombre())).append(",")
              .append(escapeCsv(p.getCategoria() != null ? p.getCategoria().getNombre() : "General")).append(",")
              .append(escapeCsv(p.getMarca())).append(",")
              .append(p.getPrecioVenta() != null ? p.getPrecioVenta().toPlainString() : "0.00").append(",")
              .append(p.getStockActual() != null ? p.getStockActual().toPlainString() : "0.000").append(",")
              .append(p.getStockMinimo() != null ? p.getStockMinimo().toPlainString() : "0.000").append(",")
              .append(Boolean.TRUE.equals(p.getEstado()) ? "ACTIVO" : "INACTIVO")
              .append("\r\n");
        }

        byte[] bom = new byte[]{(byte) 0xEF, (byte) 0xBB, (byte) 0xBF};
        byte[] content = sb.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8);
        byte[] result = new byte[bom.length + content.length];
        System.arraycopy(bom, 0, result, 0, bom.length);
        System.arraycopy(content, 0, result, bom.length, content.length);
        return result;
    }

    private String escapeCsv(String value) {
        if (value == null) return "";
        String clean = value.trim();
        if (clean.startsWith("=") || clean.startsWith("+") || clean.startsWith("-") || clean.startsWith("@") || clean.startsWith("\t") || clean.startsWith("\r")) {
            clean = "'" + clean;
        }
        if (clean.contains(",") || clean.contains("\"") || clean.contains("\n") || clean.contains("\r")) {
            clean = "\"" + clean.replace("\"", "\"\"") + "\"";
        }
        return clean;
    }
}
