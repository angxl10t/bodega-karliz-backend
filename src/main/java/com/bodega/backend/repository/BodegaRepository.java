package com.bodega.backend.repository;

import com.bodega.backend.entity.Bodega;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface BodegaRepository extends JpaRepository<Bodega, Long> {
    Optional<Bodega> findByIdBodegaAndEstadoTrue(Long idBodega);
    List<Bodega> findByEstadoTrueOrderByNombreComercialAsc();
    boolean existsByRucDni(String rucDni);
}
