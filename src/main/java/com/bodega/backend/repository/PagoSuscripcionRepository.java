package com.bodega.backend.repository;

import com.bodega.backend.entity.PagoSuscripcion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PagoSuscripcionRepository extends JpaRepository<PagoSuscripcion, Long> {

    boolean existsByBilleteraIgnoreCaseAndCodigoOperacion(String billetera, String codigoOperacion);

    List<PagoSuscripcion> findByBodega_IdBodegaOrderByFechaPagoDesc(Long idBodega);

    List<PagoSuscripcion> findAllByOrderByFechaPagoDesc();
}
