package com.bodega.backend.repository;

import com.bodega.backend.entity.Venta;
import com.bodega.backend.entity.VentaDetalle;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

@Repository
public interface VentaDetalleRepository extends JpaRepository<VentaDetalle, Long> {
    @EntityGraph(attributePaths = {"producto"})
    List<VentaDetalle> findByVenta(Venta venta);

    @EntityGraph(attributePaths = {"producto"})
    List<VentaDetalle> findByVenta_IdVenta(Long idVenta);

    @EntityGraph(attributePaths = {"producto"})
    List<VentaDetalle> findByVenta_IdVentaIn(List<Long> idsVenta);

    // =========================================================================
    // CONSULTAS AGREGADAS DE COSTOS Y ROTACIÓN (ALTA EFICIENCIA EN BD)
    // =========================================================================

    @Query("SELECT COALESCE(SUM(vd.cantidad * COALESCE(p.precioCosto, vd.precioUnitario * 0.75)), 0) " +
            "FROM VentaDetalle vd " +
            "JOIN vd.venta v " +
            "JOIN vd.producto p " +
            "WHERE v.bodega.idBodega = :idBodega AND v.estado != 'ANULADA' AND v.fechaVenta >= :start")
    BigDecimal sumTotalCostosByPeriodo(@Param("idBodega") Long idBodega, @Param("start") OffsetDateTime start);

    @Query("SELECT p.idProducto, p.nombre, p.codigo, COALESCE(p.categoria.nombre, 'General'), p.imagenUrl, " +
            "SUM(vd.cantidad), SUM(vd.subtotal), " +
            "SUM(vd.cantidad * COALESCE(p.precioCosto, vd.precioUnitario * 0.75)) " +
            "FROM VentaDetalle vd " +
            "JOIN vd.venta v " +
            "JOIN vd.producto p " +
            "WHERE v.bodega.idBodega = :idBodega AND v.estado != 'ANULADA' AND v.fechaVenta >= :start " +
            "GROUP BY p.idProducto, p.nombre, p.codigo, p.categoria.nombre, p.imagenUrl " +
            "ORDER BY (SUM(vd.subtotal) - SUM(vd.cantidad * COALESCE(p.precioCosto, vd.precioUnitario * 0.75))) DESC")
    List<Object[]> findTopEstrellasByPeriodo(@Param("idBodega") Long idBodega, @Param("start") OffsetDateTime start, Pageable pageable);
}
