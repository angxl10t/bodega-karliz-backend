package com.bodega.backend.repository;

import com.bodega.backend.entity.Presentacion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface PresentacionRepository extends JpaRepository<Presentacion, Long> {
    // Buscar presentaciones activas que pertenezcan a un producto en específico dentro del tenant
    List<Presentacion> findByProducto_IdProductoAndEstadoTrue(Long idProducto);
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"producto"})
    List<Presentacion> findByProducto_IdProductoAndProducto_Bodega_IdBodegaAndEstadoTrue(Long idProducto, Long idBodega);
    java.util.Optional<Presentacion> findByProducto_IdProductoAndNombreIgnoreCase(Long idProducto, String nombre);
    java.util.Optional<Presentacion> findByIdPresentacionAndProducto_Bodega_IdBodega(Long idPresentacion, Long idBodega);
    boolean existsByProducto_IdProductoAndNombreIgnoreCaseAndEstadoTrue(Long idProducto, String nombre);
}
