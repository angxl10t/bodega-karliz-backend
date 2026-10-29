package com.bodega.backend.repository;

import com.bodega.backend.entity.YapeTransaccionRecibida;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface YapeTransaccionRecibidaRepository extends JpaRepository<YapeTransaccionRecibida, Long> {

    boolean existsByCodigoOperacion(String codigoOperacion);

    Optional<YapeTransaccionRecibida> findFirstByCodigoOperacionAndUsadoFalse(String codigoOperacion);

    Optional<YapeTransaccionRecibida> findFirstByCodigoOperacion(String codigoOperacion);

    /**
     * Bloqueo pesimista exclusivo para serializar la conciliación de pagos y prevenir
     * condiciones de carrera (doble canje del mismo código de operación).
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT y FROM YapeTransaccionRecibida y WHERE y.codigoOperacion = :codigoOperacion")
    Optional<YapeTransaccionRecibida> findByCodigoOperacionForUpdate(@Param("codigoOperacion") String codigoOperacion);

    List<YapeTransaccionRecibida> findAllByOrderByFechaRecepcionDesc();
}
