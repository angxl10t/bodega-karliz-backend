package com.bodega.backend.repository;

import com.bodega.backend.entity.Bodega;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

@Repository
public interface BodegaRepository extends JpaRepository<Bodega, Long> {
    Optional<Bodega> findByIdBodegaAndEstadoTrue(Long idBodega);
    List<Bodega> findByEstadoTrueOrderByNombreComercialAsc();
    boolean existsByRucDni(String rucDni);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT b FROM Bodega b WHERE b.idBodega = :id")
    Optional<Bodega> findByIdForUpdate(@Param("id") Long id);
}
