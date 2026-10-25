package com.bodega.backend.repository;

import com.bodega.backend.entity.Venta;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface VentaRepository extends JpaRepository<Venta, Long> {
    List<Venta> findAllByOrderByFechaVentaDesc();
    List<Venta> findTop150ByOrderByFechaVentaDesc();
    List<Venta> findByFechaVentaBetweenOrderByFechaVentaDesc(OffsetDateTime start, OffsetDateTime end);

    List<Venta> findByBodega_IdBodegaOrderByFechaVentaDesc(Long idBodega);
    List<Venta> findTop150ByBodega_IdBodegaOrderByFechaVentaDesc(Long idBodega);
    List<Venta> findByBodega_IdBodegaAndFechaVentaBetweenOrderByFechaVentaDesc(Long idBodega, OffsetDateTime start, OffsetDateTime end);

    List<Venta> findByCliente_IdClienteOrderByFechaVentaDesc(Long idCliente);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT v FROM Venta v WHERE v.idVenta = :id")
    Optional<Venta> findByIdForUpdate(@Param("id") Long id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT v FROM Venta v WHERE v.idVenta = :id AND v.bodega.idBodega = :idBodega")
    Optional<Venta> findByIdForUpdateAndBodega(@Param("id") Long id, @Param("idBodega") Long idBodega);

    Optional<Venta> findByBodega_IdBodegaAndIdempotencyKey(Long idBodega, String idempotencyKey);

    // =========================================================================
    // CONSULTAS AGREGADAS NATIVAS DE ALTO RENDIMIENTO (PREVENCIÓN OOM / HIKARI)
    // =========================================================================

    @Query("SELECT COALESCE(SUM(v.total), 0) FROM Venta v WHERE v.bodega.idBodega = :idBodega AND v.estado != 'ANULADA' AND v.fechaVenta >= :start")
    BigDecimal sumTotalVentasByPeriodo(@Param("idBodega") Long idBodega, @Param("start") OffsetDateTime start);

    @Query("SELECT COUNT(v) FROM Venta v WHERE v.bodega.idBodega = :idBodega AND v.estado != 'ANULADA' AND v.fechaVenta >= :start")
    long countVentasByPeriodo(@Param("idBodega") Long idBodega, @Param("start") OffsetDateTime start);

    @Query(value = "SELECT EXTRACT(HOUR FROM (v.fecha_venta AT TIME ZONE 'America/Lima'))\\:\\:int as hora, " +
            "COUNT(v.id_venta) as tickets, " +
            "COALESCE(SUM(v.total), 0) as ventas " +
            "FROM ventas v " +
            "WHERE v.id_bodega = :idBodega AND v.estado != 'ANULADA' AND v.fecha_venta >= :start " +
            "GROUP BY hora " +
            "ORDER BY hora", nativeQuery = true)
    List<Object[]> findDistribucionHorariaNative(@Param("idBodega") Long idBodega, @Param("start") OffsetDateTime start);
}
