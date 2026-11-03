package com.bodega.backend.repository;

import com.bodega.backend.entity.BoletaConsolidada;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface BoletaConsolidadaRepository extends JpaRepository<BoletaConsolidada, Long> {
    Optional<BoletaConsolidada> findByBodega_IdBodegaAndFechaEmision(Long idBodega, LocalDate fechaEmision);
    List<BoletaConsolidada> findByBodega_IdBodegaOrderByFechaEmisionDesc(Long idBodega);
    List<BoletaConsolidada> findTop30ByBodega_IdBodegaOrderByFechaEmisionDesc(Long idBodega);
    List<BoletaConsolidada> findByBodega_IdBodegaAndFechaEmisionBetweenOrderByFechaEmisionDesc(Long idBodega, LocalDate start, LocalDate end);
}
