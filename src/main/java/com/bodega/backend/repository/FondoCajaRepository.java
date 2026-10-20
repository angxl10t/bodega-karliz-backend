package com.bodega.backend.repository;

import com.bodega.backend.entity.FondoCaja;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface FondoCajaRepository extends JpaRepository<FondoCaja, Long> {
    Optional<FondoCaja> findByBodega_IdBodegaAndFecha(Long idBodega, LocalDate fecha);

    List<FondoCaja> findByBodega_IdBodegaOrderByFechaDesc(Long idBodega);

    long countByBodega_IdBodega(Long idBodega);
}
