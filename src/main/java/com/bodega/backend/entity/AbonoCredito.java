package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "abonos_credito",
    indexes = {
        @Index(name = "idx_abonos_cliente", columnList = "id_cliente, fecha_abono DESC"),
        @Index(name = "idx_abonos_bodega", columnList = "id_bodega, fecha_abono DESC")
    }
)
public class AbonoCredito {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_abono")
    private Long idAbono;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega", nullable = false)
    private Bodega bodega;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_cliente", nullable = false)
    private Cliente cliente;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal monto;

    @Column(name = "metodo_pago", nullable = false, length = 50)
    private String metodoPago = "Efectivo";

    @Column(name = "saldo_anterior", nullable = false, precision = 12, scale = 2)
    private BigDecimal saldoAnterior;

    @Column(name = "saldo_restante", nullable = false, precision = 12, scale = 2)
    private BigDecimal saldoRestante;

    @Column(name = "comprobante_numero", length = 30)
    private String comprobanteNumero;

    @Column(name = "notas", length = 255)
    private String notas;

    @Column(name = "usuario_registro", length = 50)
    private String usuarioRegistro;

    @CreationTimestamp
    @Column(name = "fecha_abono", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaAbono;
}
