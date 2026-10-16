package com.bodega.backend.repository;

import com.bodega.backend.entity.Categoria;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CategoriaRepository extends JpaRepository<Categoria, Long> {
    List<Categoria> findByEstadoTrue();
    List<Categoria> findByBodega_IdBodegaAndEstadoTrue(Long idBodega);

    Optional<Categoria> findByNombreIgnoreCase(String nombre);
    Optional<Categoria> findByBodega_IdBodegaAndNombreIgnoreCase(Long idBodega, String nombre);

    boolean existsByNombreIgnoreCase(String nombre);
    boolean existsByBodega_IdBodegaAndNombreIgnoreCase(Long idBodega, String nombre);

    boolean existsByNombreIgnoreCaseAndIdCategoriaNot(String nombre, Long idCategoria);
    boolean existsByBodega_IdBodegaAndNombreIgnoreCaseAndIdCategoriaNot(Long idBodega, String nombre, Long idCategoria);

    Optional<Categoria> findByIdCategoriaAndBodega_IdBodega(Long idCategoria, Long idBodega);
}
