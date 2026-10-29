package com.bodega.backend.repository;

import com.bodega.backend.entity.YapeTransaccionRecibida;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface YapeTransaccionRecibidaRepository extends JpaRepository<YapeTransaccionRecibida, Long> {

    boolean existsByCodigoOperacion(String codigoOperacion);

    Optional<YapeTransaccionRecibida> findFirstByCodigoOperacionAndUsadoFalse(String codigoOperacion);

    Optional<YapeTransaccionRecibida> findFirstByCodigoOperacion(String codigoOperacion);

    List<YapeTransaccionRecibida> findAllByOrderByFechaRecepcionDesc();
}
