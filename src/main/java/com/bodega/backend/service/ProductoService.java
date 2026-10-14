package com.bodega.backend.service;

import com.bodega.backend.dto.ProductoDTO;
import com.bodega.backend.entity.Categoria;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.ProductoRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class ProductoService {

    private final ProductoRepository productoRepository;
    private final CategoriaRepository categoriaRepository;

    public ProductoService(ProductoRepository productoRepository, CategoriaRepository categoriaRepository) {
        this.productoRepository = productoRepository;
        this.categoriaRepository = categoriaRepository;
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
        if (productoRepository.findByCodigo(dto.getCodigo()).isPresent()) {
            throw new RuntimeException("Ya existe un producto con el código interno: " + dto.getCodigo());
        }
        if (dto.getCodigoBarras() != null && !dto.getCodigoBarras().isEmpty() &&
            productoRepository.findByCodigoBarras(dto.getCodigoBarras()).isPresent()) {
            throw new RuntimeException("Ya existe un producto con el código de barras: " + dto.getCodigoBarras());
        }

        Producto producto = new Producto();
        producto.setCategoria(categoria);
        producto.setCodigo(dto.getCodigo());
        producto.setCodigoBarras(dto.getCodigoBarras());
        producto.setNombre(dto.getNombre());
        producto.setMarca(dto.getMarca());
        producto.setPrecioVenta(dto.getPrecioVenta());
        producto.setStockActual(dto.getStockActual());
        producto.setStockMinimo(dto.getStockMinimo());
        
        // RN-09
        producto.setControlaVencimiento(dto.getControlaVencimiento() != null ? dto.getControlaVencimiento() : false);

        Producto guardado = productoRepository.save(producto);
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
            productoRepository.findByCodigo(dto.getCodigo())
                    .filter(otro -> !otro.getIdProducto().equals(id))
                    .ifPresent(otro -> {
                        throw new RuntimeException("Ya existe otro producto con el código: " + dto.getCodigo());
                    });
            producto.setCodigo(dto.getCodigo());
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
            producto.setStockActual(dto.getStockActual());
        }
        if (dto.getStockMinimo() != null) {
            producto.setStockMinimo(dto.getStockMinimo());
        }
        if (dto.getCodigoBarras() != null) {
            if (!dto.getCodigoBarras().isBlank()) {
                productoRepository.findByCodigoBarras(dto.getCodigoBarras())
                        .filter(otro -> !otro.getIdProducto().equals(id))
                        .ifPresent(otro -> {
                            throw new RuntimeException("Ya existe otro producto con el código de barras: " + dto.getCodigoBarras());
                        });
                producto.setCodigoBarras(dto.getCodigoBarras());
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
        productoRepository.save(producto);
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
