package com.bodega.backend.repository;

import com.bodega.backend.entity.SugerenciaPrecioSuperadmin;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SugerenciaPrecioRepository extends JpaRepository<SugerenciaPrecioSuperadmin, Long> {

    @EntityGraph(attributePaths = {"bodega", "producto"})
    List<SugerenciaPrecioSuperadmin> findByBodega_IdBodegaAndEstadoOrderByFechaCreacionDesc(Long idBodega, String estado);

    @EntityGraph(attributePaths = {"bodega", "producto"})
    List<SugerenciaPrecioSuperadmin> findByBodega_IdBodegaOrderByFechaCreacionDesc(Long idBodega);

    long countByBodega_IdBodegaAndEstado(Long idBodega, String estado);

    @EntityGraph(attributePaths = {"bodega", "producto"})
    List<SugerenciaPrecioSuperadmin> findAllByOrderByFechaCreacionDesc();

    @EntityGraph(attributePaths = {"bodega", "producto"})
    List<SugerenciaPrecioSuperadmin> findByEstadoOrderByFechaCreacionDesc(String estado);

    Optional<SugerenciaPrecioSuperadmin> findByBodega_IdBodegaAndCodigoBarrasAndEstado(Long idBodega, String codigoBarras, String estado);

    @Query("SELECT COUNT(DISTINCT p.bodega.idBodega) FROM Producto p WHERE p.codigoBarras = :codigoBarras AND p.estado = true")
    long countBodegasConProducto(@Param("codigoBarras") String codigoBarras);
}
