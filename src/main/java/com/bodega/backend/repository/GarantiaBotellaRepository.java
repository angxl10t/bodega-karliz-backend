package com.bodega.backend.repository;

import com.bodega.backend.entity.GarantiaBotella;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface GarantiaBotellaRepository extends JpaRepository<GarantiaBotella, Long> {

    List<GarantiaBotella> findByBodega_IdBodegaOrderByFechaRegistroDesc(Long idBodega);

    List<GarantiaBotella> findByBodega_IdBodegaAndEstadoOrderByFechaRegistroDesc(Long idBodega, String estado);

    Optional<GarantiaBotella> findByIdGarantiaAndBodega_IdBodega(Long idGarantia, Long idBodega);

    @Query("SELECT g FROM GarantiaBotella g WHERE g.bodega.idBodega = :idBodega " +
           "AND (:estado IS NULL OR g.estado = :estado) " +
           "AND (LOWER(g.nombrePersona) LIKE LOWER(CONCAT('%', :query, '%')) " +
           "     OR LOWER(COALESCE(g.telefono, '')) LIKE LOWER(CONCAT('%', :query, '%')) " +
           "     OR LOWER(COALESCE(g.tipoBotella, '')) LIKE LOWER(CONCAT('%', :query, '%'))) " +
           "ORDER BY g.fechaRegistro DESC")
    List<GarantiaBotella> buscarGarantias(
            @Param("idBodega") Long idBodega,
            @Param("estado") String estado,
            @Param("query") String query
    );

    @Query("SELECT g FROM GarantiaBotella g WHERE g.bodega.idBodega = :idBodega " +
           "AND g.fechaDevolucion >= :desde")
    List<GarantiaBotella> findDevolucionesDesde(
            @Param("idBodega") Long idBodega,
            @Param("desde") OffsetDateTime desde
    );
}
