package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.BatchSize;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Data
@Entity
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "pedidos_web",
    indexes = {
        @Index(name = "idx_pedidos_web_bodega_estado", columnList = "id_bodega, estado"),
        @Index(name = "idx_pedidos_web_bodega_fecha", columnList = "id_bodega, fecha_creacion DESC"),
        @Index(name = "idx_pedidos_web_bodega_codigo", columnList = "id_bodega, codigo_pedido")
    }
)
public class PedidoWeb {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_pedido_web")
    private Long idPedidoWeb;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega", nullable = false)
    private Bodega bodega;

    @Column(name = "codigo_pedido", nullable = false, length = 50)
    private String codigoPedido;

    @Column(name = "nombre_cliente", nullable = false, length = 150)
    private String nombreCliente;

    @Column(name = "telefono_cliente", length = 50)
    private String telefonoCliente;

    @Column(name = "notas", columnDefinition = "TEXT")
    private String notas;

    @Builder.Default
    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal total = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "ahorro_promociones", precision = 12, scale = 2)
    private BigDecimal ahorroPromociones = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "incluye_retornables")
    private Boolean incluyeRetornables = false;

    @Builder.Default
    @Column(nullable = false, length = 30)
    private String estado = "PENDIENTE";

    @CreationTimestamp
    @Column(name = "fecha_creacion", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaCreacion;

    @UpdateTimestamp
    @Column(name = "fecha_actualizacion", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaActualizacion;

    @Builder.Default
    @BatchSize(size = 50)
    @OneToMany(mappedBy = "pedidoWeb", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<PedidoWebDetalle> detalles = new ArrayList<>();

    public void agregarDetalle(PedidoWebDetalle detalle) {
        if (detalles == null) {
            detalles = new ArrayList<>();
        }
        detalles.add(detalle);
        detalle.setPedidoWeb(this);
        if (this.bodega != null) {
            detalle.setBodega(this.bodega);
        }
    }
}
