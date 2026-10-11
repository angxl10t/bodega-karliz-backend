package com.bodega.backend.repository;

import com.bodega.backend.entity.Producto;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ProductoRepository extends JpaRepository<Producto, Long> {
    List<Producto> findByEstadoTrue();
    
    // Para validar que no se repitan códigos (Reglas RN-01 y RN-02)
    Optional<Producto> findByCodigo(String codigo);
    Optional<Producto> findByCodigoBarras(String codigoBarras);
}
