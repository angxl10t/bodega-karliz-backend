package com.bodega.backend.repository;

import com.bodega.backend.entity.Compra;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CompraRepository extends JpaRepository<Compra, Long> {
    @EntityGraph(attributePaths = {"proveedor"})
    List<Compra> findAllByOrderByFechaCompraDesc();

    @EntityGraph(attributePaths = {"proveedor"})
    List<Compra> findTop150ByOrderByFechaCompraDesc();
    boolean existsByProveedor_IdProveedorAndComprobanteIgnoreCase(Long idProveedor, String comprobante);
}
