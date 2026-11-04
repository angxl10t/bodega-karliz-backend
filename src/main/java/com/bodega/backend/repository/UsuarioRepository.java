package com.bodega.backend.repository;

import com.bodega.backend.entity.Usuario;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UsuarioRepository extends JpaRepository<Usuario, Long> {
    @EntityGraph(attributePaths = {"bodega"})
    Optional<Usuario> findByUsername(String username);

    @EntityGraph(attributePaths = {"bodega"})
    Optional<Usuario> findByUsernameIgnoreCase(String username);

    @EntityGraph(attributePaths = {"bodega"})
    Optional<Usuario> findByEmailIgnoreCase(String email);

    @Query("SELECT u FROM Usuario u LEFT JOIN FETCH u.bodega WHERE LOWER(u.username) = LOWER(:term) OR LOWER(u.email) = LOWER(:term)")
    Optional<Usuario> findByUsernameOrEmailIgnoreCase(@Param("term") String term);

    boolean existsByUsername(String username);
    boolean existsByUsernameIgnoreCase(String username);

    @EntityGraph(attributePaths = {"bodega"})
    List<Usuario> findAllByOrderByRolAscUsernameAsc();

    @EntityGraph(attributePaths = {"bodega"})
    List<Usuario> findByBodega_IdBodegaOrderByRolAscUsernameAsc(Long idBodega);

    long countByBodega_IdBodegaAndEstadoTrue(Long idBodega);
}
