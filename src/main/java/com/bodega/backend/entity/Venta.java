package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "ventas", indexes = {
    @Index(name = "idx_ventas_bodega_fecha", columnList = "id_bodega, fecha_venta DESC"),
    @Index(name = "idx_ventas_bodega_idemp", columnList = "id_bodega, idempotency_key"),
    @Index(name = "idx_ventas_fecha", columnList = "fecha_venta DESC"),
    @Index(name = "idx_ventas_estado", columnList = "estado"),
    @Index(name = "idx_ventas_cliente", columnList = "id_cliente")
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

    // Facturación y Comprobantes (TICKET, BOLETA_ELECTRONICA, FACTURA_ELECTRONICA)
    @Column(name = "tipo_comprobante", length = 30)
    private String tipoComprobante = "TICKET";

    @Column(name = "serie_correlativo", length = 30)
    private String serieCorrelativo;

    @Column(name = "estado_sunat", length = 30)
    private String estadoSunat;

    @Column(name = "sunat_hash", length = 255)
    private String sunatHash;

    @Column(name = "sunat_mensaje", columnDefinition = "TEXT")
    private String sunatMensaje;

    @Column(name = "sunat_cdr_url", length = 500)
    private String sunatCdrUrl;

    @Column(name = "sunat_pdf_url", length = 500)
    private String sunatPdfUrl;

    @Column(name = "sunat_xml_url", length = 500)
    private String sunatXmlUrl;

    // Auditoría de Caja: Monto pagado en efectivo y vuelto entregado al cliente
    @Column(name = "monto_recibido", precision = 12, scale = 2)
    private BigDecimal montoRecibido;

    @Column(name = "vuelto", precision = 12, scale = 2)
    private BigDecimal vuelto;

    // Idempotencia para prevenir doble cobro o duplicidad por reintentos de red
    @Column(name = "idempotency_key", length = 64)
    private String idempotencyKey;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_cliente")
    private Cliente cliente;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega")
    private Bodega bodega;
}
