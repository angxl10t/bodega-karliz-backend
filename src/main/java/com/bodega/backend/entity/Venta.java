package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "ventas", indexes = {
    @Index(name = "idx_ventas_fecha", columnList = "fecha_venta DESC"),
    @Index(name = "idx_ventas_estado", columnList = "estado")
})
public class Venta {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_venta")
    private Long idVenta;

    @Column(name = "cliente_documento", length = 20)
    private String clienteDocumento;

    @Column(name = "cliente_nombre", length = 150)
    private String clienteNombre;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal total;

    @Column(name = "metodo_pago", length = 50)
    private String metodoPago;

    @CreationTimestamp
    @Column(name = "fecha_venta", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaVenta;

    // Auditoría: Nombre del cajero o administrador que emitió la venta
    @Column(name = "usuario_registro", length = 50)
    private String usuarioRegistro;

    // Estado de la transacción para Soft-Delete contable ("COMPLETADA" | "ANULADA")
    @Column(name = "estado", length = 20)
    private String estado = "COMPLETADA";

    @Column(name = "fecha_anulacion", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaAnulacion;

    @Column(name = "usuario_anulacion", length = 50)
    private String usuarioAnulacion;

    @Column(name = "motivo_anulacion", length = 255)
    private String motivoAnulacion;
}
