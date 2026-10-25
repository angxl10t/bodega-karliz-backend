package com.bodega.backend.repository;

import com.bodega.backend.entity.Venta;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

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
}
