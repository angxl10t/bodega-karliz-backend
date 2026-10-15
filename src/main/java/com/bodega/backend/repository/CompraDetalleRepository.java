package com.bodega.backend.repository;
import com.bodega.backend.entity.CompraDetalle;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface CompraDetalleRepository extends JpaRepository<CompraDetalle, Long> {
    List<CompraDetalle> findByCompra_IdCompra(Long idCompra);
    List<CompraDetalle> findByCompra_IdCompraIn(List<Long> idsCompra);
}
