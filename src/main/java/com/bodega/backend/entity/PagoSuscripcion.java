package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * Entidad de Libro Mayor y Auditoría de Pagos de Suscripciones SaaS (CajaYa Cloud Platform)
 * Garantiza idempotencia de pagos y trazabilidad fiscal de renovaciones vía Yape / Plin.
 */
@Data
@Entity
@Table(name = "pagos_suscripciones",
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_pagos_billetera_operacion", columnNames = {"billetera", "codigo_operacion"})
    },
    indexes = {
        @Index(name = "idx_pagos_bodega_fecha", columnList = "id_bodega, fecha_pago DESC"),
        @Index(name = "idx_pagos_fecha", columnList = "fecha_pago DESC")
    }
)
public class PagoSuscripcion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_pago")
    private Long idPago;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega", nullable = false)
    private Bodega bodega;

    @Column(name = "codigo_operacion", nullable = false, length = 50)
    private String codigoOperacion;

    @Column(nullable = false, length = 30)
    private String billetera; // YAPE, PLIN, TRANSFERENCIA

    @Column(nullable = false, length = 30)
    private String plan; // BASICO, PRO

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal monto;

    @CreationTimestamp
    @Column(name = "fecha_pago", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaPago;

    @Column(name = "usuario_registro", length = 50)
    private String usuarioRegistro;

    @Column(nullable = false, length = 30)
    private String estado = "CONFIRMADO";
}
