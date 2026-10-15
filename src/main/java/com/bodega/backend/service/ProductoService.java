package com.bodega.backend.service;

import com.bodega.backend.dto.ProductoDTO;
import com.bodega.backend.entity.Categoria;
import com.bodega.backend.entity.MovimientoInventario;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.MovimientoInventarioRepository;
import com.bodega.backend.repository.ProductoRepository;
import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class ProductoService {

    private final ProductoRepository productoRepository;
    private final CategoriaRepository categoriaRepository;
    private final MovimientoInventarioRepository movimientoInventarioRepository;

    public ProductoService(ProductoRepository productoRepository, 
                           CategoriaRepository categoriaRepository,
                           MovimientoInventarioRepository movimientoInventarioRepository) {
        this.productoRepository = productoRepository;
        this.categoriaRepository = categoriaRepository;
        this.movimientoInventarioRepository = movimientoInventarioRepository;
    }

    @PostConstruct
    @Transactional
    public void liberarCodigosInactivos() {
        try {
            List<Producto> inactivos = productoRepository.findAll().stream()
                    .filter(p -> Boolean.FALSE.equals(p.getEstado()))
                    .collect(Collectors.toList());
            for (Producto p : inactivos) {
                boolean modificado = false;
                if (p.getCodigoBarras() != null && !p.getCodigoBarras().isBlank()) {
                    p.setCodigoBarras(null);
                    modificado = true;
                }
                if (p.getCodigo() != null && !p.getCodigo().contains("_BAJA_")) {
                    String base = p.getCodigo();
                    if (base.length() > 30) base = base.substring(0, 30);
                    p.setCodigo(base + "_BAJA_" + p.getIdProducto());
                    modificado = true;
                }
                if (modificado) {
                    productoRepository.save(p);
                }
            }
        } catch (Exception ignored) {}
    }

    @Transactional(readOnly = true)
    public List<ProductoDTO> listarActivos() {
        return productoRepository.findByEstadoTrue()
                .stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
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
    public String generarSiguienteCodigo(Long idCategoria) {
        Categoria categoria = categoriaRepository.findById(idCategoria)
                .orElseThrow(() -> new RuntimeException("Categoría no encontrada con ID: " + idCategoria));
        String prefix = getPrefixForCategoria(categoria.getNombre());
        List<Producto> productos = productoRepository.findAll();
        int maxNum = 0;
        java.util.regex.Pattern pattern = java.util.regex.Pattern.compile("^" + java.util.regex.Pattern.quote(prefix) + "-(\\d+)$");
        for (Producto p : productos) {
            if (p.getCodigo() != null) {
                java.util.regex.Matcher m = pattern.matcher(p.getCodigo().trim());
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
        // Enlazar con la categoría
        Categoria categoria = categoriaRepository.findById(dto.getIdCategoria())
                .orElseThrow(() -> new RuntimeException("Categoría no encontrada con ID: " + dto.getIdCategoria()));

        // Generar código según categoría si no fue proporcionado
        if (dto.getCodigo() == null || dto.getCodigo().isBlank()) {
            dto.setCodigo(generarSiguienteCodigo(categoria.getIdCategoria()));
        }

        // Validaciones de reglas de negocio
        if (dto.getCodigo() != null && !dto.getCodigo().isBlank()) {
            productoRepository.findByCodigo(dto.getCodigo().trim()).ifPresent(existente -> {
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
            productoRepository.findByCodigoBarras(dto.getCodigoBarras().trim()).ifPresent(existente -> {
                if (Boolean.TRUE.equals(existente.getEstado())) {
                    throw new RuntimeException("Ya existe un producto activo con el código de barras: " + dto.getCodigoBarras() + " (" + existente.getNombre() + ")");
                } else {
                    // Si el producto anterior fue dado de baja (por error o descarte), liberar su código de barras
                    existente.setCodigoBarras(null);
                    productoRepository.saveAndFlush(existente);
                }
            });
        }

        Producto producto = new Producto();
        producto.setCategoria(categoria);
        producto.setCodigo(dto.getCodigo().trim());
        producto.setCodigoBarras(dto.getCodigoBarras() != null && !dto.getCodigoBarras().isBlank() ? dto.getCodigoBarras().trim() : null);
        producto.setNombre(dto.getNombre());
        producto.setMarca(dto.getMarca());
        producto.setPrecioVenta(dto.getPrecioVenta());
        producto.setStockActual(dto.getStockActual());
        producto.setStockMinimo(dto.getStockMinimo());
        
        // RN-09
        producto.setControlaVencimiento(dto.getControlaVencimiento() != null ? dto.getControlaVencimiento() : false);

        Producto guardado = productoRepository.save(producto);

        // Auditoría Kardex: Si el producto se registra con existencias iniciales, registrar entrada
        if (guardado.getStockActual() != null && guardado.getStockActual().compareTo(BigDecimal.ZERO) > 0) {
            MovimientoInventario mov = new MovimientoInventario();
            mov.setProducto(guardado);
            mov.setTipoMovimiento("ENTRADA");
            mov.setCantidad(guardado.getStockActual());
            mov.setMotivo("Inventario Inicial de Apertura");
            mov.setUsuarioResponsable(obtenerUsuarioActual());
            movimientoInventarioRepository.save(mov);
        }

        return mapToDTO(guardado);
    }

    @Transactional
    public ProductoDTO actualizar(Long id, ProductoDTO dto) {
        Producto producto = productoRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Producto no encontrado con ID: " + id));

        if (dto.getIdCategoria() != null) {
            Categoria categoria = categoriaRepository.findById(dto.getIdCategoria())
                    .orElseThrow(() -> new RuntimeException("Categoría no encontrada con ID: " + dto.getIdCategoria()));
            producto.setCategoria(categoria);
        }

        if (dto.getCodigo() != null && !dto.getCodigo().isBlank()) {
            productoRepository.findByCodigo(dto.getCodigo().trim())
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
        if (dto.getNombre() != null && !dto.getNombre().isBlank()) {
            producto.setNombre(dto.getNombre());
        }
        if (dto.getMarca() != null) {
            producto.setMarca(dto.getMarca());
        }
        if (dto.getPrecioVenta() != null) {
            producto.setPrecioVenta(dto.getPrecioVenta());
        }
        if (dto.getStockActual() != null) {
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
                movimientoInventarioRepository.save(mov);
            }
            producto.setStockActual(nuevoStock);
        }
        if (dto.getStockMinimo() != null) {
            producto.setStockMinimo(dto.getStockMinimo());
        }
        if (dto.getCodigoBarras() != null) {
            if (!dto.getCodigoBarras().isBlank()) {
                productoRepository.findByCodigoBarras(dto.getCodigoBarras().trim())
                        .filter(otro -> !otro.getIdProducto().equals(id))
                        .ifPresent(otro -> {
                            if (Boolean.TRUE.equals(otro.getEstado())) {
                                throw new RuntimeException("Ya existe otro producto activo con el código de barras: " + dto.getCodigoBarras());
                            } else {
                                otro.setCodigoBarras(null);
                                productoRepository.saveAndFlush(otro);
                            }
                        });
                producto.setCodigoBarras(dto.getCodigoBarras().trim());
            } else {
                producto.setCodigoBarras(null);
            }
        }
        if (dto.getControlaVencimiento() != null) {
            producto.setControlaVencimiento(dto.getControlaVencimiento());
        }

        Producto actualizado = productoRepository.save(producto);
        return mapToDTO(actualizado);
    }

    @Transactional
    public void desactivar(Long id) {
        Producto producto = productoRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Producto no encontrado con ID: " + id));
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
        dto.setIdCategoria(producto.getCategoria().getIdCategoria());
        dto.setNombreCategoria(producto.getCategoria().getNombre());
        dto.setCodigo(producto.getCodigo());
        dto.setCodigoBarras(producto.getCodigoBarras());
        dto.setNombre(producto.getNombre());
        dto.setMarca(producto.getMarca());
        dto.setPrecioVenta(producto.getPrecioVenta());
        dto.setStockActual(producto.getStockActual());
        dto.setStockMinimo(producto.getStockMinimo());
        dto.setControlaVencimiento(producto.getControlaVencimiento());
        dto.setEstado(producto.getEstado());
        return dto;
    }
}
