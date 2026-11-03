package com.bodega.backend.repository;

import com.bodega.backend.entity.Reclamacion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ReclamacionRepository extends JpaRepository<Reclamacion, Long> {

    Optional<Reclamacion> findByCodigoReclamacion(String codigoReclamacion);

    List<Reclamacion> findByBodega_IdBodegaOrderByFechaReclamoDesc(Long idBodega);

    List<Reclamacion> findAllByOrderByFechaReclamoDesc();

    @Query(value = "SELECT nextval('seq_reclamaciones_correlativo')", nativeQuery = true)
    Long obtenerSiguienteCorrelativo();
}
