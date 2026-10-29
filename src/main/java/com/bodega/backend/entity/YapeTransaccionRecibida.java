package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * Entidad de Transacciones Yape / Plin Recibidas en Tiempo Real.
 * Registra automáticamente las notificaciones push emitidas por el BCP / Interbank
 * capturadas por el bot listener en el teléfono del titular (Luis T.).
 * Permite conciliación autónoma sin intervención humana.
 */
@Data
@Entity
@Table(name = "yape_transacciones_recibidas",
    indexes = {
        @Index(name = "idx_yape_tx_cod_op", columnList = "codigo_operacion"),
        @Index(name = "idx_yape_tx_usado", columnList = "usado"),
        @Index(name = "idx_yape_tx_fecha", columnList = "fecha_recepcion DESC")
    }
)
public class YapeTransaccionRecibida {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_transaccion")
    private Long idTransaccion;

    @Column(name = "codigo_operacion", nullable = false, length = 50)
    private String codigoOperacion;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal monto;

    @Column(nullable = false, length = 30)
    private String billetera = "YAPE"; // YAPE, PLIN

    @Column(name = "nombre_remitente", length = 120)
    private String nombreRemitente;

    @Column(name = "texto_notificacion", length = 1000)
    private String textoNotificacion;

    @CreationTimestamp
    @Column(name = "fecha_recepcion", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaRecepcion;

    @Column(nullable = false)
    private boolean usado = false;

    @Column(name = "id_bodega_asignada")
    private Long idBodegaAsignada;

    @Column(name = "fecha_uso", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaUso;
}
