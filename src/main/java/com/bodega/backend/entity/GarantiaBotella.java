package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "garantias_botellas",
    indexes = {
        @Index(name = "idx_garantias_botellas_bodega_fecha", columnList = "id_bodega, fecha_registro DESC"),
        @Index(name = "idx_garantias_botellas_bodega_estado", columnList = "id_bodega, estado"),
        @Index(name = "idx_garantias_botellas_cliente", columnList = "id_bodega, id_cliente")
    }
)
public class GarantiaBotella {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_garantia")
    private Long idGarantia;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega", nullable = false)
    private Bodega bodega;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_cliente")
    private Cliente cliente;

    @Column(name = "nombre_persona", nullable = false, length = 150)
    private String nombrePersona;

    @Column(name = "telefono", length = 30)
    private String telefono;

    @Column(name = "cantidad_botellas", nullable = false)
    private Integer cantidadBotellas = 1;

    @Column(name = "monto_garantia", nullable = false, precision = 12, scale = 2)
    private BigDecimal montoGarantia = BigDecimal.ZERO;

    @Column(name = "tipo_botella", length = 100)
    private String tipoBotella;

    @Column(name = "notas", length = 255)
    private String notas;

    @Column(name = "estado", nullable = false, length = 20)
    private String estado = "PENDIENTE"; // PENDIENTE, DEVUELTO, CANCELADO

    @Column(name = "botellas_devueltas", nullable = false)
    private Integer botellasDevueltas = 0;

    @Column(name = "monto_devuelto", nullable = false, precision = 12, scale = 2)
    private BigDecimal montoDevuelto = BigDecimal.ZERO;

    @CreationTimestamp
    @Column(name = "fecha_registro", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaRegistro;

    @Column(name = "fecha_devolucion", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaDevolucion;

    @Column(name = "usuario_registro", length = 50)
    private String usuarioRegistro;
}
