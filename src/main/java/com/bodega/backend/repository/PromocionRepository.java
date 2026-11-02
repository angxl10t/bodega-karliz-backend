package com.bodega.backend.repository;

import com.bodega.backend.entity.Promocion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PromocionRepository extends JpaRepository<Promocion, Long> {

    List<Promocion> findByBodega_IdBodegaOrderByFechaCreacionDesc(Long idBodega);

    List<Promocion> findByBodega_IdBodegaAndActivoTrue(Long idBodega);

    Optional<Promocion> findByIdPromocionAndBodega_IdBodega(Long idPromocion, Long idBodega);
}
