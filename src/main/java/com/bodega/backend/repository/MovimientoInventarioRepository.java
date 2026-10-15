package com.bodega.backend.repository;

import com.bodega.backend.entity.MovimientoInventario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MovimientoInventarioRepository extends JpaRepository<MovimientoInventario, Long> {
    List<MovimientoInventario> findByProducto_IdProductoOrderByFechaMovimientoDesc(Long idProducto);
    List<MovimientoInventario> findTop100ByProducto_IdProductoOrderByFechaMovimientoDesc(Long idProducto);
    List<MovimientoInventario> findAllByOrderByFechaMovimientoDesc();
    List<MovimientoInventario> findTop200ByOrderByFechaMovimientoDesc();
}
