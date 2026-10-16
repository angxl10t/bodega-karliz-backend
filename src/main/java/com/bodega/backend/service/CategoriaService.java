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
    private final TenantService tenantService;

    public CategoriaService(CategoriaRepository categoriaRepository, 
                            ProductoRepository productoRepository,
                            TenantService tenantService) {
        this.categoriaRepository = categoriaRepository;
        this.productoRepository = productoRepository;
        this.tenantService = tenantService;
    }

    @Transactional(readOnly = true)
    public List<CategoriaDTO> listarActivas() {
        Long idBodega = tenantService.getCurrentBodegaId();
        return categoriaRepository.findByBodega_IdBodegaAndEstadoTrue(idBodega)
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
        Long idBodega = tenantService.getCurrentBodegaId();

        java.util.Optional<Categoria> existente = categoriaRepository.findByBodega_IdBodegaAndNombreIgnoreCase(idBodega, nombreTrim);
        if (existente.isPresent()) {
            Categoria cat = existente.get();
            if (Boolean.FALSE.equals(cat.getEstado())) {
                // Reactivación transparente de categoría previamente dada de baja
                cat.setEstado(true);
                if (dto.getDescripcion() != null && !dto.getDescripcion().isBlank()) {
                    cat.setDescripcion(dto.getDescripcion().trim());
                }
                Categoria reactivada = categoriaRepository.save(cat);
                return mapToDTO(reactivada);
            }
            throw new RuntimeException("Ya existe una categoría activa con el nombre: " + nombreTrim);
        }

        Categoria categoria = new Categoria();
        categoria.setBodega(tenantService.getCurrentBodega());
        categoria.setNombre(nombreTrim);
        categoria.setDescripcion(dto.getDescripcion() != null ? dto.getDescripcion().trim() : null);
        
        Categoria guardada = categoriaRepository.save(categoria);
        return mapToDTO(guardada);
    }

    @Transactional
    public CategoriaDTO actualizar(Long id, CategoriaDTO dto) {
        Long idBodega = tenantService.getCurrentBodegaId();
        Categoria categoria = categoriaRepository.findByIdCategoriaAndBodega_IdBodega(id, idBodega)
                .orElseThrow(() -> new RuntimeException("Categoría no encontrada con ID: " + id));

        if (Boolean.FALSE.equals(categoria.getEstado())) {
            throw new RuntimeException("No se puede editar una categoría inactiva o dada de baja. Debe reactivarla primero.");
        }

        if (dto.getNombre() == null || dto.getNombre().trim().isBlank()) {
            throw new RuntimeException("El nombre de la categoría es obligatorio");
        }
        String nombreTrim = dto.getNombre().trim();
        if (categoriaRepository.existsByBodega_IdBodegaAndNombreIgnoreCaseAndIdCategoriaNot(idBodega, nombreTrim, id)) {
            throw new RuntimeException("Ya existe otra categoría con el nombre: " + nombreTrim);
        }

        categoria.setNombre(nombreTrim);
        categoria.setDescripcion(dto.getDescripcion() != null ? dto.getDescripcion().trim() : null);

        Categoria guardada = categoriaRepository.save(categoria);
        return mapToDTO(guardada);
    }

    @Transactional
    public void desactivar(Long id) {
        Long idBodega = tenantService.getCurrentBodegaId();
        Categoria categoria = categoriaRepository.findByIdCategoriaAndBodega_IdBodega(id, idBodega)
                .orElseThrow(() -> new RuntimeException("Categoría no encontrada con ID: " + id));

        if (Boolean.FALSE.equals(categoria.getEstado())) {
            return;
        }

        // Integridad referencial multi-inquilino: Impedir desactivar categorías que tengan productos activos vinculados
        if (productoRepository.existsByCategoria_IdCategoriaAndBodega_IdBodegaAndEstadoTrue(id, idBodega)) {
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
