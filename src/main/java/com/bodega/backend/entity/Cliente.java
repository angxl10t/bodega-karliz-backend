package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "clientes",
    indexes = {
        @Index(name = "idx_clientes_bodega", columnList = "id_bodega"),
        @Index(name = "idx_clientes_doc", columnList = "id_bodega, documento"),
        @Index(name = "idx_clientes_deuda", columnList = "id_bodega, saldo_deudor DESC")
    }
)
public class Cliente {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_cliente")
    private Long idCliente;

    @Column(name = "documento", length = 20)
    private String documento;

    @Column(name = "nombre_completo", nullable = false, length = 150)
    private String nombreCompleto;

    @Column(name = "telefono", length = 30)
    private String telefono;

    @Column(name = "direccion", length = 255)
    private String direccion;

    @Column(name = "limite_credito", nullable = false, precision = 12, scale = 2)
    private BigDecimal limiteCredito = new BigDecimal("200.00");

    @Column(name = "saldo_deudor", nullable = false, precision = 12, scale = 2)
    private BigDecimal saldoDeudor = BigDecimal.ZERO;

    @Column(name = "notas", columnDefinition = "TEXT")
    private String notas;

    @Column(name = "estado", nullable = false)
    private Boolean estado = true;

    @CreationTimestamp
    @Column(name = "fecha_registro", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaRegistro;

    @Column(name = "fecha_ultimo_pago", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaUltimoPago;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega", nullable = false)
    private Bodega bodega;
}
