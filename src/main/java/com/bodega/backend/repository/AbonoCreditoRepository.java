package com.bodega.backend.repository;

import com.bodega.backend.entity.AbonoCredito;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

@Repository
public interface AbonoCreditoRepository extends JpaRepository<AbonoCredito, Long> {
    List<AbonoCredito> findByCliente_IdClienteOrderByFechaAbonoDesc(Long idCliente);

    List<AbonoCredito> findByBodega_IdBodegaOrderByFechaAbonoDesc(Long idBodega);

    List<AbonoCredito> findByBodega_IdBodegaAndFechaAbonoBetweenOrderByFechaAbonoDesc(
            Long idBodega, OffsetDateTime inicio, OffsetDateTime fin);

    @Query("SELECT COALESCE(SUM(a.monto), 0) FROM AbonoCredito a " +
           "WHERE a.bodega.idBodega = :idBodega AND a.fechaAbono >= :desde")
    BigDecimal totalAbonosDesde(@Param("idBodega") Long idBodega, @Param("desde") OffsetDateTime desde);
}
