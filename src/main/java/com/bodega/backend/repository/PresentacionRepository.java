package com.bodega.backend.repository;

import com.bodega.backend.entity.Presentacion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface PresentacionRepository extends JpaRepository<Presentacion, Long> {
    // Buscar presentaciones activas que pertenezcan a un producto en específico
    List<Presentacion> findByProducto_IdProductoAndEstadoTrue(Long idProducto);
    java.util.Optional<Presentacion> findByProducto_IdProductoAndNombreIgnoreCase(Long idProducto, String nombre);
    boolean existsByProducto_IdProductoAndNombreIgnoreCaseAndEstadoTrue(Long idProducto, String nombre);
}
