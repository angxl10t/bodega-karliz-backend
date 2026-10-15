package com.bodega.backend.repository;

import com.bodega.backend.entity.Venta;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public interface VentaRepository extends JpaRepository<Venta, Long> {
    List<Venta> findAllByOrderByFechaVentaDesc();
    List<Venta> findTop150ByOrderByFechaVentaDesc();
    List<Venta> findByFechaVentaBetweenOrderByFechaVentaDesc(OffsetDateTime start, OffsetDateTime end);
}
