package com.bodega.backend.service;

import com.bodega.backend.dto.CategoriaDTO;
import com.bodega.backend.entity.Categoria;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.ProductoRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class CategoriaService {

    private final CategoriaRepository categoriaRepository;
    private final ProductoRepository productoRepository;

    public CategoriaService(CategoriaRepository categoriaRepository, ProductoRepository productoRepository) {
        this.categoriaRepository = categoriaRepository;
        this.productoRepository = productoRepository;
    }

    @Transactional(readOnly = true)
    public List<CategoriaDTO> listarActivas() {
        return categoriaRepository.findByEstadoTrue()
                .stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public CategoriaDTO crear(CategoriaDTO dto) {
        if (dto.getNombre() == null || dto.getNombre().trim().isBlank()) {
            throw new RuntimeException("El nombre de la categoría es obligatorio");
        }
        String nombreTrim = dto.getNombre().trim();
        if (categoriaRepository.existsByNombreIgnoreCase(nombreTrim)) {
            throw new RuntimeException("Ya existe una categoría con el nombre: " + nombreTrim);
        }

        Categoria categoria = new Categoria();
        categoria.setNombre(nombreTrim);
        categoria.setDescripcion(dto.getDescripcion() != null ? dto.getDescripcion().trim() : null);
        
        Categoria guardada = categoriaRepository.save(categoria);
        return mapToDTO(guardada);
    }

    @Transactional
    public CategoriaDTO actualizar(Long id, CategoriaDTO dto) {
        Categoria categoria = categoriaRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Categoría no encontrada con ID: " + id));

        if (Boolean.FALSE.equals(categoria.getEstado())) {
            throw new RuntimeException("No se puede editar una categoría inactiva o dada de baja. Debe reactivarla primero.");
        }

        if (dto.getNombre() == null || dto.getNombre().trim().isBlank()) {
            throw new RuntimeException("El nombre de la categoría es obligatorio");
        }
        String nombreTrim = dto.getNombre().trim();
        if (categoriaRepository.existsByNombreIgnoreCaseAndIdCategoriaNot(nombreTrim, id)) {
            throw new RuntimeException("Ya existe otra categoría con el nombre: " + nombreTrim);
        }

        categoria.setNombre(nombreTrim);
        categoria.setDescripcion(dto.getDescripcion() != null ? dto.getDescripcion().trim() : null);

        Categoria guardada = categoriaRepository.save(categoria);
        return mapToDTO(guardada);
    }

    @Transactional
    public void desactivar(Long id) {
        Categoria categoria = categoriaRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Categoría no encontrada con ID: " + id));

        // Integridad referencial: Impedir desactivar categorías que tengan productos activos vinculados
        if (productoRepository.existsByCategoria_IdCategoriaAndEstadoTrue(id)) {
            throw new RuntimeException("No se puede desactivar la categoría '" + categoria.getNombre() + 
                                       "' porque tiene productos activos asociados. Debe reasignar o desactivar los productos primero.");
        }

        categoria.setEstado(false);
        categoriaRepository.save(categoria);
    }

    // Método utilitario para convertir de Entidad a DTO
    private CategoriaDTO mapToDTO(Categoria categoria) {
        CategoriaDTO dto = new CategoriaDTO();
        dto.setIdCategoria(categoria.getIdCategoria());
        dto.setNombre(categoria.getNombre());
        dto.setDescripcion(categoria.getDescripcion());
        dto.setEstado(categoria.getEstado());
        return dto;
    }
}
