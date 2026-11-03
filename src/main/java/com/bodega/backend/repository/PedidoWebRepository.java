package com.bodega.backend.repository;

import com.bodega.backend.entity.PedidoWeb;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PedidoWebRepository extends JpaRepository<PedidoWeb, Long> {

    List<PedidoWeb> findByBodegaIdBodegaOrderByFechaCreacionDesc(Long idBodega, Pageable pageable);

    List<PedidoWeb> findByBodegaIdBodegaAndEstadoOrderByFechaCreacionDesc(Long idBodega, String estado, Pageable pageable);

    Optional<PedidoWeb> findByIdPedidoWebAndBodegaIdBodega(Long idPedidoWeb, Long idBodega);

    Optional<PedidoWeb> findByCodigoPedidoAndBodegaIdBodega(String codigoPedido, Long idBodega);

    long countByBodegaIdBodegaAndEstado(Long idBodega, String estado);

    @Query("SELECT p FROM PedidoWeb p WHERE p.bodega.idBodega = :idBodega AND (LOWER(p.codigoPedido) LIKE LOWER(CONCAT('%', :filtro, '%')) OR LOWER(p.nombreCliente) LIKE LOWER(CONCAT('%', :filtro, '%')) OR (p.telefonoCliente IS NOT NULL AND LOWER(p.telefonoCliente) LIKE LOWER(CONCAT('%', :filtro, '%')))) ORDER BY p.fechaCreacion DESC")
    List<PedidoWeb> buscarPorFiltro(@Param("idBodega") Long idBodega, @Param("filtro") String filtro, Pageable pageable);
}
