package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.OffsetDateTime;

@Data
@Entity
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "notificaciones",
    indexes = {
        @Index(name = "idx_notif_bodega_leido", columnList = "id_bodega, leido, fecha_creacion DESC"),
        @Index(name = "idx_notif_bodega_usuario", columnList = "id_bodega, id_usuario_destinatario, leido"),
        @Index(name = "idx_notif_bodega_rol", columnList = "id_bodega, rol_destinatario, leido")
    }
)
public class Notificacion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_notificacion")
    private Long idNotificacion;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega", nullable = false)
    private Bodega bodega;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario_destinatario")
    private Usuario usuarioDestinatario;

    @Builder.Default
    @Column(name = "rol_destinatario", nullable = false, length = 30)
    private String rolDestinatario = "TODOS";

    @Column(name = "tipo", nullable = false, length = 50)
    private String tipo;

    @Column(name = "titulo", nullable = false, length = 150)
    private String titulo;

    @Column(name = "mensaje", nullable = false, columnDefinition = "TEXT")
    private String mensaje;

    @Column(name = "metadata_json", columnDefinition = "TEXT")
    private String metadataJson;

    @Builder.Default
    @Column(name = "prioridad", nullable = false, length = 20)
    private String prioridad = "MEDIA";

    @Builder.Default
    @Column(name = "leido", nullable = false)
    private Boolean leido = false;

    @CreationTimestamp
    @Column(name = "fecha_creacion", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaCreacion;

    @Column(name = "fecha_leido", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaLeido;
}
