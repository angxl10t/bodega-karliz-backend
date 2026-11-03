package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

/**
 * Registro de Boleta Consolidada Diaria del Nuevo RUS (Res. SUNAT N° 007-99 Art. 8, Num 3.2).
 * Comprende el total de las ventas con consumidores finales menores o iguales a S/ 5.00
 * por las cuales no se emitió boleta individual durante el día.
 */
@Data
@Entity
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "boletas_consolidadas", indexes = {
    @Index(name = "idx_boletas_consolidadas_bodega_fecha", columnList = "id_bodega, fecha_emision DESC"),
    @Index(name = "idx_boletas_consolidadas_bodega_serie", columnList = "id_bodega, serie_correlativo")
})
public class BoletaConsolidada {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_boleta_consolidada")
    private Long idBoletaConsolidada;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega", nullable = false)
    private Bodega bodega;

    @Column(name = "fecha_emision", nullable = false)
    private LocalDate fechaEmision;

    @Column(name = "monto_total", nullable = false, precision = 12, scale = 2)
    private BigDecimal montoTotal;

    @Column(name = "cantidad_operaciones", nullable = false)
    private Integer cantidadOperaciones;

    @Column(name = "serie_correlativo", nullable = false, length = 30)
    private String serieCorrelativo;

    @Column(name = "tipo_emision", nullable = false, length = 30)
    private String tipoEmision; // "TALONARIO_FISICO" | "DIGITAL_CAJAYA"

    @Column(name = "observaciones", length = 255)
    private String observaciones;

    @Column(name = "usuario_registro", length = 50)
    private String usuarioRegistro;

    @CreationTimestamp
    @Column(name = "fecha_registro", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaRegistro;
}
