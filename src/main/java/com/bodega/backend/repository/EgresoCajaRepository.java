package com.bodega.backend.repository;

import com.bodega.backend.entity.EgresoCaja;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface EgresoCajaRepository extends JpaRepository<EgresoCaja, Long> {
    List<EgresoCaja> findByBodega_IdBodegaAndEstadoTrueOrderByFechaEgresoDesc(Long idBodega);

    List<EgresoCaja> findByBodega_IdBodegaAndFechaEgresoBetweenAndEstadoTrueOrderByFechaEgresoDesc(
            Long idBodega, OffsetDateTime inicio, OffsetDateTime fin);

    Optional<EgresoCaja> findByIdEgresoAndBodega_IdBodega(Long idEgreso, Long idBodega);

    long countByBodega_IdBodega(Long idBodega);
}
