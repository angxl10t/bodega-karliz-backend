package com.bodega.backend.repository;

import com.bodega.backend.entity.Proveedor;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ProveedorRepository extends JpaRepository<Proveedor, Long> {
    List<Proveedor> findByEstadoTrue();
    List<Proveedor> findByBodega_IdBodegaAndEstadoTrue(Long idBodega);

    Optional<Proveedor> findByRuc(String ruc);
    Optional<Proveedor> findByBodega_IdBodegaAndRuc(Long idBodega, String ruc);

    Optional<Proveedor> findByIdProveedorAndBodega_IdBodega(Long idProveedor, Long idBodega);
}
