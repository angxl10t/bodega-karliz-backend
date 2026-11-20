package com.bodega.backend.repository;

import com.bodega.backend.entity.TerminalPOS;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TerminalRepository extends JpaRepository<TerminalPOS, Long> {

    Optional<TerminalPOS> findByTerminalTokenAndEstadoTrue(String terminalToken);

    Optional<TerminalPOS> findByTerminalToken(String terminalToken);

    List<TerminalPOS> findByBodega_IdBodegaOrderByFechaVinculacionDesc(Long idBodega);

    List<TerminalPOS> findByBodega_IdBodegaAndEstadoTrueOrderByFechaVinculacionDesc(Long idBodega);

    long countByBodega_IdBodegaAndEstadoTrue(Long idBodega);
}
