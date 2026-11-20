package com.bodega.backend.repository;

import com.bodega.backend.entity.TerminalPairingCode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface TerminalPairingCodeRepository extends JpaRepository<TerminalPairingCode, Long> {

    Optional<TerminalPairingCode> findByCodigoAndUsadoFalse(String codigo);

    List<TerminalPairingCode> findByBodega_IdBodegaAndUsadoFalseAndFechaExpiracionAfter(Long idBodega, OffsetDateTime now);

    void deleteByFechaExpiracionBefore(OffsetDateTime now);
}
