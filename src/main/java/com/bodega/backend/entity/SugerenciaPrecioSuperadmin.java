package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "sugerencias_precio_superadmin", indexes = {
        @Index(name = "idx_sug_bodega_estado", columnList = "id_bodega, estado"),
        @Index(name = "idx_sug_codigo_barras", columnList = "codigo_barras")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SugerenciaPrecioSuperadmin {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_sugerencia")
    private Long idSugerencia;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega", nullable = false)
    private Bodega bodega;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_producto", nullable = false)
    private Producto producto;

    @Column(name = "codigo_barras", nullable = false, length = 100)
    private String codigoBarras;

    @Column(name = "nombre_actual", nullable = false, length = 150)
    private String nombreActual;

    @Column(name = "nombre_sugerido", length = 150)
    private String nombreSugerido;

    @Column(name = "marca_actual", length = 100)
    private String marcaActual;

    @Column(name = "marca_sugerida", length = 100)
    private String marcaSugerida;

    @Column(name = "precio_venta_actual", nullable = false, precision = 12, scale = 2)
    private BigDecimal precioVentaActual;

    @Column(name = "precio_venta_sugerido", nullable = false, precision = 12, scale = 2)
    private BigDecimal precioVentaSugerido;

    @Column(name = "precio_costo_actual", precision = 12, scale = 2)
    private BigDecimal precioCostoActual;

    @Column(name = "precio_costo_sugerido", precision = 12, scale = 2)
    private BigDecimal precioCostoSugerido;

    @Column(name = "motivo", length = 500)
    private String motivo;

    @Column(name = "estado", nullable = false, length = 20)
    @Builder.Default
    private String estado = "PENDIENTE";

    @CreationTimestamp
    @Column(name = "fecha_creacion", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaCreacion;

    @Column(name = "fecha_resolucion", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaResolucion;

    @Column(name = "usuario_resolucion", length = 100)
    private String usuarioResolucion;
}
