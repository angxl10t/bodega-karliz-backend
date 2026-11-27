package com.bodega.backend.repository;

import com.bodega.backend.entity.Notificacion;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public interface NotificacionRepository extends JpaRepository<Notificacion, Long> {

    @Query("SELECT n FROM Notificacion n WHERE n.bodega.idBodega = :idBodega " +
           "AND (n.usuarioDestinatario.idUsuario = :idUsuario OR n.usuarioDestinatario IS NULL) " +
           "AND (n.rolDestinatario = 'TODOS' OR n.rolDestinatario = :rol OR n.rolDestinatario IS NULL) " +
           "ORDER BY n.fechaCreacion DESC")
    List<Notificacion> listarPorBodegaYDestinatario(
            @Param("idBodega") Long idBodega,
            @Param("idUsuario") Long idUsuario,
            @Param("rol") String rol,
            Pageable pageable
    );

    @Query("SELECT COUNT(n) FROM Notificacion n WHERE n.bodega.idBodega = :idBodega " +
           "AND n.leido = false " +
           "AND (n.usuarioDestinatario.idUsuario = :idUsuario OR n.usuarioDestinatario IS NULL) " +
           "AND (n.rolDestinatario = 'TODOS' OR n.rolDestinatario = :rol OR n.rolDestinatario IS NULL)")
    long contarNoLeidas(
            @Param("idBodega") Long idBodega,
            @Param("idUsuario") Long idUsuario,
            @Param("rol") String rol
    );

    @Modifying
    @Query("UPDATE Notificacion n SET n.leido = true, n.fechaLeido = :ahora " +
           "WHERE n.bodega.idBodega = :idBodega " +
           "AND n.leido = false " +
           "AND (n.usuarioDestinatario.idUsuario = :idUsuario OR n.usuarioDestinatario IS NULL) " +
           "AND (n.rolDestinatario = 'TODOS' OR n.rolDestinatario = :rol OR n.rolDestinatario IS NULL)")
    int marcarTodasComoLeidas(
            @Param("idBodega") Long idBodega,
            @Param("idUsuario") Long idUsuario,
            @Param("rol") String rol,
            @Param("ahora") OffsetDateTime ahora
    );

    @Query("SELECT COUNT(n) > 0 FROM Notificacion n WHERE n.bodega.idBodega = :idBodega " +
           "AND n.tipo = 'STOCK_CRITICO' " +
           "AND n.leido = false " +
           "AND n.metadataJson LIKE CONCAT('%', :prodFilter, '%') " +
           "AND (:tituloLike IS NULL OR n.titulo LIKE :tituloLike)")
    boolean existeAlertaStockPendiente(
            @Param("idBodega") Long idBodega,
            @Param("prodFilter") String prodFilter,
            @Param("tituloLike") String tituloLike
    );
}
