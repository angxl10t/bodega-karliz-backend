package com.bodega.backend.repository;

import com.bodega.backend.entity.Compra;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

@Repository
public interface CompraRepository extends JpaRepository<Compra, Long> {
    @EntityGraph(attributePaths = {"proveedor"})
    List<Compra> findAllByOrderByFechaCompraDesc();

    @EntityGraph(attributePaths = {"proveedor"})
    List<Compra> findTop150ByOrderByFechaCompraDesc();

    @EntityGraph(attributePaths = {"proveedor"})
    List<Compra> findTop150ByBodega_IdBodegaOrderByFechaCompraDesc(Long idBodega);

    boolean existsByProveedor_IdProveedorAndComprobanteIgnoreCase(Long idProveedor, String comprobante);
    boolean existsByBodega_IdBodegaAndProveedor_IdProveedorAndComprobanteIgnoreCase(Long idBodega, Long idProveedor, String comprobante);

    @Query("SELECT COALESCE(SUM(c.total), 0) FROM Compra c WHERE c.bodega.idBodega = :idBodega AND c.fechaCompra >= :start AND c.fechaCompra < :end")
    BigDecimal sumTotalComprasByBodegaAndRangoFechas(@Param("idBodega") Long idBodega, @Param("start") OffsetDateTime start, @Param("end") OffsetDateTime end);
}
