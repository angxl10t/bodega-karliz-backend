package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "egresos_caja", indexes = {
    @Index(name = "idx_egresos_caja_bodega_fecha", columnList = "id_bodega, fecha_egreso DESC"),
    @Index(name = "idx_egresos_caja_bodega_estado", columnList = "id_bodega, estado")
})
public class EgresoCaja {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_egreso")
    private Long idEgreso;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega", nullable = false)
    private Bodega bodega;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal monto;

    @Column(nullable = false, length = 255)
    private String motivo;

    @Column(name = "categoria_gasto", length = 50)
    private String categoriaGasto;

    @CreationTimestamp
    @Column(name = "fecha_egreso", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaEgreso;

    @Column(name = "usuario_registro", length = 50)
    private String usuarioRegistro;

    @Column(nullable = false)
    private Boolean estado = true;

    @Column(name = "usuario_anulacion", length = 50)
    private String usuarioAnulacion;

    @Column(name = "motivo_anulacion", length = 255)
    private String motivoAnulacion;

    @Column(name = "fecha_anulacion", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaAnulacion;
}
