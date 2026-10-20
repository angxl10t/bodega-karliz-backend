package com.bodega.backend.repository;

import com.bodega.backend.entity.Producto;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ProductoRepository extends JpaRepository<Producto, Long> {
    @EntityGraph(attributePaths = {"categoria"})
    List<Producto> findByEstadoTrue();

    @EntityGraph(attributePaths = {"categoria"})
    List<Producto> findByBodega_IdBodegaAndEstadoTrue(Long idBodega);

    long countByBodega_IdBodegaAndEstadoTrue(Long idBodega);

    @Query("SELECT p.bodega.idBodega, COUNT(p) FROM Producto p WHERE p.estado = true GROUP BY p.bodega.idBodega")
    List<Object[]> countActiveProductsGroupedByBodega();

    List<Producto> findByEstadoFalse();
    List<Producto> findByBodega_IdBodegaAndEstadoFalse(Long idBodega);
    
    // Para validar que no se repitan códigos (Reglas RN-01 y RN-02)
    Optional<Producto> findByCodigo(String codigo);
    Optional<Producto> findByBodega_IdBodegaAndCodigo(Long idBodega, String codigo);

    Optional<Producto> findByCodigoBarras(String codigoBarras);
    Optional<Producto> findByBodega_IdBodegaAndCodigoBarras(Long idBodega, String codigoBarras);

    List<Producto> findByCodigoStartingWith(String prefix);
    List<Producto> findByBodega_IdBodegaAndCodigoStartingWith(Long idBodega, String prefix);

    boolean existsByCategoria_IdCategoriaAndEstadoTrue(Long idCategoria);
    boolean existsByCategoria_IdCategoriaAndBodega_IdBodegaAndEstadoTrue(Long idCategoria, Long idBodega);

    @EntityGraph(attributePaths = {"categoria"})
    Optional<Producto> findByIdProductoAndBodega_IdBodega(Long idProducto, Long idBodega);

    // Bloqueo pesimista (SELECT ... FOR UPDATE) para evitar condiciones de carrera (Race Condition) en ventas concurrentes
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT p FROM Producto p WHERE p.idProducto = :id")
    Optional<Producto> findByIdForUpdate(@Param("id") Long id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT p FROM Producto p WHERE p.idProducto = :id AND p.bodega.idBodega = :idBodega")
    Optional<Producto> findByIdForUpdateAndBodega(@Param("id") Long id, @Param("idBodega") Long idBodega);
}
