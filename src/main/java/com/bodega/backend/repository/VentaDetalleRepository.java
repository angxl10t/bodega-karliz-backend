package com.bodega.backend.repository;

import com.bodega.backend.entity.Venta;
import com.bodega.backend.entity.VentaDetalle;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface VentaDetalleRepository extends JpaRepository<VentaDetalle, Long> {
    List<VentaDetalle> findByVenta(Venta venta);
    List<VentaDetalle> findByVenta_IdVenta(Long idVenta);
}
