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

    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @org.springframework.data.jpa.repository.Query("SELECT bc FROM BoletaConsolidada bc WHERE bc.bodega.idBodega = :idBodega AND bc.fechaEmision = :fechaEmision")
    Optional<BoletaConsolidada> findByBodegaAndFechaEmisionForUpdate(@org.springframework.data.repository.query.Param("idBodega") Long idBodega, @org.springframework.data.repository.query.Param("fechaEmision") LocalDate fechaEmision);
    List<BoletaConsolidada> findByBodega_IdBodegaOrderByFechaEmisionDesc(Long idBodega);
    List<BoletaConsolidada> findTop30ByBodega_IdBodegaOrderByFechaEmisionDesc(Long idBodega);
    List<BoletaConsolidada> findByBodega_IdBodegaAndFechaEmisionBetweenOrderByFechaEmisionDesc(Long idBodega, LocalDate start, LocalDate end);
}
