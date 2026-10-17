package com.bodega.backend.repository;

import com.bodega.backend.entity.MovimientoInventario;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MovimientoInventarioRepository extends JpaRepository<MovimientoInventario, Long> {
    List<MovimientoInventario> findByProducto_IdProductoOrderByFechaMovimientoDesc(Long idProducto);

    @EntityGraph(attributePaths = {"producto"})
    List<MovimientoInventario> findTop100ByProducto_IdProductoOrderByFechaMovimientoDesc(Long idProducto);

    List<MovimientoInventario> findAllByOrderByFechaMovimientoDesc();

    @EntityGraph(attributePaths = {"producto"})
    List<MovimientoInventario> findTop200ByOrderByFechaMovimientoDesc();

    @EntityGraph(attributePaths = {"producto"})
    List<MovimientoInventario> findTop200ByProducto_Bodega_IdBodegaOrderByFechaMovimientoDesc(Long idBodega);

    @EntityGraph(attributePaths = {"producto"})
    List<MovimientoInventario> findTop100ByProducto_IdProductoAndProducto_Bodega_IdBodegaOrderByFechaMovimientoDesc(Long idProducto, Long idBodega);
}
