package com.bodega.backend.repository;

import com.bodega.backend.entity.RecuperacionClave;
import com.bodega.backend.entity.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public interface RecuperacionClaveRepository extends JpaRepository<RecuperacionClave, Long> {

    List<RecuperacionClave> findByUsuarioAndUsadoFalseAndExpiracionAfterOrderByFechaCreacionDesc(
            Usuario usuario, OffsetDateTime now);

    long countByUsuarioAndFechaCreacionAfter(Usuario usuario, OffsetDateTime after);

    List<RecuperacionClave> findByUsuarioAndUsadoFalse(Usuario usuario);
}
