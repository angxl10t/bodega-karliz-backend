package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "fondos_caja", 
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_fondos_caja_bodega_fecha", columnNames = {"id_bodega", "fecha"})
    },
    indexes = {
        @Index(name = "idx_fondos_caja_bodega_fecha", columnList = "id_bodega, fecha")
    }
)
public class FondoCaja {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_fondo_caja")
    private Long idFondoCaja;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega", nullable = false)
    private Bodega bodega;

    @Column(nullable = false)
    private LocalDate fecha;

    @Column(name = "monto_inicial", nullable = false, precision = 12, scale = 2)
    private BigDecimal montoInicial;

    @Column(name = "usuario_registro", length = 50)
    private String usuarioRegistro;

    @CreationTimestamp
    @Column(name = "fecha_registro", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaRegistro;
}
