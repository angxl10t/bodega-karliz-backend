package com.bodega.backend.repository;

import com.bodega.backend.entity.Producto;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ProductoRepository extends JpaRepository<Producto, Long> {
    List<Producto> findByEstadoTrue();
    List<Producto> findByEstadoFalse();
    
    // Para validar que no se repitan códigos (Reglas RN-01 y RN-02)
    Optional<Producto> findByCodigo(String codigo);
    Optional<Producto> findByCodigoBarras(String codigoBarras);
    List<Producto> findByCodigoStartingWith(String prefix);

    // Bloqueo pesimista (SELECT ... FOR UPDATE) para evitar condiciones de carrera (Race Condition) en ventas concurrentes
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT p FROM Producto p WHERE p.idProducto = :id")
    Optional<Producto> findByIdForUpdate(@Param("id") Long id);
}
