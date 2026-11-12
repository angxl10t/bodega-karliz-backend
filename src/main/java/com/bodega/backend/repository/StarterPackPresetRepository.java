package com.bodega.backend.repository;

import com.bodega.backend.entity.StarterPackPreset;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface StarterPackPresetRepository extends JpaRepository<StarterPackPreset, Long> {
    List<StarterPackPreset> findByActivoTrueOrderByIdPresetAsc();
    List<StarterPackPreset> findAllByOrderByIdPresetAsc();
    Optional<StarterPackPreset> findByCodigoBarras(String codigoBarras);
    boolean existsByCodigoBarras(String codigoBarras);
}
