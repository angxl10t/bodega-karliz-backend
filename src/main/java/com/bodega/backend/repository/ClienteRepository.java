package com.bodega.backend.repository;

import com.bodega.backend.entity.Cliente;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

@Repository
public interface ClienteRepository extends JpaRepository<Cliente, Long> {
    List<Cliente> findByBodega_IdBodegaAndEstadoTrueOrderByNombreCompletoAsc(Long idBodega);

    List<Cliente> findByBodega_IdBodegaAndEstadoTrueAndSaldoDeudorGreaterThanOrderBySaldoDeudorDesc(Long idBodega, BigDecimal saldoMinimo);

    Optional<Cliente> findByIdClienteAndBodega_IdBodega(Long idCliente, Long idBodega);

    Optional<Cliente> findByBodega_IdBodegaAndDocumentoAndEstadoTrue(Long idBodega, String documento);

    @Query("SELECT c FROM Cliente c WHERE c.bodega.idBodega = :idBodega AND c.estado = true " +
           "AND (LOWER(c.nombreCompleto) LIKE LOWER(CONCAT('%', :query, '%')) " +
           "OR (c.documento IS NOT NULL AND c.documento LIKE CONCAT('%', :query, '%')) " +
           "OR (c.telefono IS NOT NULL AND c.telefono LIKE CONCAT('%', :query, '%'))) " +
           "ORDER BY c.nombreCompleto ASC")
    List<Cliente> buscarClientes(@Param("idBodega") Long idBodega, @Param("query") String query);

    @Query("SELECT COUNT(c), COALESCE(SUM(c.saldoDeudor), 0) FROM Cliente c " +
           "WHERE c.bodega.idBodega = :idBodega AND c.estado = true AND c.saldoDeudor > 0")
    List<Object[]> obtenerResumenCreditos(@Param("idBodega") Long idBodega);
}
