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

    @Transactional
    public ProductoDTO crear(ProductoDTO dto) {
        // Validaciones de reglas de negocio
        if (productoRepository.findByCodigo(dto.getCodigo()).isPresent()) {
            throw new RuntimeException("Ya existe un producto con el código interno: " + dto.getCodigo());
        }
        if (dto.getCodigoBarras() != null && !dto.getCodigoBarras().isEmpty() &&
            productoRepository.findByCodigoBarras(dto.getCodigoBarras()).isPresent()) {
            throw new RuntimeException("Ya existe un producto con el código de barras: " + dto.getCodigoBarras());
        }

        // Enlazar con la categoría
        Categoria categoria = categoriaRepository.findById(dto.getIdCategoria())
                .orElseThrow(() -> new RuntimeException("Categoría no encontrada con ID: " + dto.getIdCategoria()));

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
