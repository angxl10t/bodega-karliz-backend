package com.bodega.backend.repository;

import com.bodega.backend.entity.PagoSuscripcion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PagoSuscripcionRepository extends JpaRepository<PagoSuscripcion, Long> {

    boolean existsByBilleteraIgnoreCaseAndCodigoOperacion(String billetera, String codigoOperacion);

    boolean existsByCodigoOperacionIgnoreCase(String codigoOperacion);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"bodega"})
    List<PagoSuscripcion> findByBodega_IdBodegaOrderByFechaPagoDesc(Long idBodega);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"bodega"})
    List<PagoSuscripcion> findTop100ByBodega_IdBodegaOrderByFechaPagoDesc(Long idBodega);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"bodega"})
    List<PagoSuscripcion> findAllByOrderByFechaPagoDesc();

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"bodega"})
    List<PagoSuscripcion> findTop200ByOrderByFechaPagoDesc();

    @org.springframework.data.jpa.repository.Query("SELECT COALESCE(SUM(p.monto), 0) FROM PagoSuscripcion p")
    java.math.BigDecimal sumarTotalRecaudado();
}
