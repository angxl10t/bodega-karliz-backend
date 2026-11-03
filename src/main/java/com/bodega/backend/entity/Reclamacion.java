package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@Entity
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "reclamaciones",
    indexes = {
        @Index(name = "idx_reclamaciones_codigo", columnList = "codigo_reclamacion"),
        @Index(name = "idx_reclamaciones_bodega", columnList = "id_bodega"),
        @Index(name = "idx_reclamaciones_estado", columnList = "estado"),
        @Index(name = "idx_reclamaciones_fecha", columnList = "fecha_reclamo DESC")
    }
)
public class Reclamacion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_reclamacion")
    private Long idReclamacion;

    @Column(name = "codigo_reclamacion", nullable = false, unique = true, length = 50)
    private String codigoReclamacion;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega")
    private Bodega bodega;

    @Column(name = "nombre_reclamante", nullable = false, length = 150)
    private String nombreReclamante;

    @Column(name = "tipo_documento", nullable = false, length = 20)
    private String tipoDocumento; // DNI, CE, PASAPORTE, RUC

    @Column(name = "numero_documento", nullable = false, length = 30)
    private String numeroDocumento;

    @Column(length = 50)
    private String telefono;

    @Column(nullable = false, length = 150)
    private String email;

    @Column(length = 250)
    private String direccion;

    @Builder.Default
    @Column(nullable = false, length = 20)
    private String tipo = "RECLAMO"; // 'RECLAMO' (bien/servicio) o 'QUEJA' (atención)

    @Builder.Default
    @Column(name = "tipo_bien", nullable = false, length = 20)
    private String tipoBien = "PRODUCTO"; // 'PRODUCTO' o 'SERVICIO'

    @Builder.Default
    @Column(name = "monto_reclamado", precision = 12, scale = 2)
    private BigDecimal montoReclamado = BigDecimal.ZERO;

    @Column(name = "descripcion_bien", columnDefinition = "TEXT")
    private String descripcionBien;

    @Column(name = "detalle_reclamacion", nullable = false, columnDefinition = "TEXT")
    private String detalleReclamacion;

    @Column(name = "pedido_reclamante", nullable = false, columnDefinition = "TEXT")
    private String pedidoReclamante;

    @Builder.Default
    @Column(nullable = false, length = 30)
    private String estado = "PENDIENTE"; // 'PENDIENTE', 'EN_PROCESO', 'ATENDIDO'

    @Column(name = "respuesta_proveedor", columnDefinition = "TEXT")
    private String respuestaProveedor;

    @CreationTimestamp
    @Column(name = "fecha_reclamo", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaReclamo;

    @Column(name = "fecha_respuesta", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaRespuesta;
}
