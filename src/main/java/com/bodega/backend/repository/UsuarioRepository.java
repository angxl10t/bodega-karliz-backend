package com.bodega.backend.repository;

import com.bodega.backend.entity.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface UsuarioRepository extends JpaRepository<Usuario, Long> {
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"bodega"})
    Optional<Usuario> findByUsername(String username);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"bodega"})
    Optional<Usuario> findByUsernameIgnoreCase(String username);

    boolean existsByUsername(String username);
    boolean existsByUsernameIgnoreCase(String username);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"bodega"})
    java.util.List<Usuario> findAllByOrderByRolAscUsernameAsc();

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"bodega"})
    java.util.List<Usuario> findByBodega_IdBodegaOrderByRolAscUsernameAsc(Long idBodega);
    long countByBodega_IdBodegaAndEstadoTrue(Long idBodega);
}
