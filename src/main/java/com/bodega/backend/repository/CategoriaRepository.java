package com.bodega.backend.repository;

import com.bodega.backend.entity.Categoria;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CategoriaRepository extends JpaRepository<Categoria, Long> {
    // Método automático de Spring Data para buscar solo las categorías activas
    List<Categoria> findByEstadoTrue();
    Optional<Categoria> findByNombreIgnoreCase(String nombre);
    boolean existsByNombreIgnoreCase(String nombre);
    boolean existsByNombreIgnoreCaseAndIdCategoriaNot(String nombre, Long idCategoria);
}
