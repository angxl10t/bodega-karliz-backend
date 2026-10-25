package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "productos", 
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_productos_bodega_codigo", columnNames = {"id_bodega", "codigo"}),
        @UniqueConstraint(name = "uk_productos_bodega_codigo_barras", columnNames = {"id_bodega", "codigo_barras"})
    },
    indexes = {
        @Index(name = "idx_productos_bodega_estado", columnList = "id_bodega, estado"),
        @Index(name = "idx_productos_estado_categoria", columnList = "estado, id_categoria")
    }
)
public class Producto {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_producto")
    private Long idProducto;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_categoria", nullable = false)
    private Categoria categoria;

    @Column(nullable = false, length = 50)
    private String codigo;

    @Column(name = "codigo_barras", length = 100)
    private String codigoBarras;

    @Column(nullable = false, length = 150)
    private String nombre;

    @Column(length = 100)
    private String marca;

    // NUMERIC(12,2) para dinero
    @Column(name = "precio_venta", nullable = false, precision = 12, scale = 2)
    private BigDecimal precioVenta;

    // NUMERIC(12,3) para cantidades (por conversiones de presentación)
    @Column(name = "stock_actual", nullable = false, precision = 12, scale = 3)
    private BigDecimal stockActual;

    @Column(name = "stock_minimo", nullable = false, precision = 12, scale = 3)
    private BigDecimal stockMinimo;

    @Column(name = "controla_vencimiento", nullable = false)
    private Boolean controlaVencimiento = false;

    @Column(name = "fecha_vencimiento")
    private java.time.LocalDate fechaVencimiento;

    @Column(name = "precio_costo", precision = 12, scale = 2)
    private BigDecimal precioCosto;

    @Column(name = "imagen_url", length = 500)
    private String imagenUrl;

    @Column(nullable = false)
    private Boolean estado = true;

    @CreationTimestamp
    @Column(name = "fecha_creacion", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaCreacion;

    @UpdateTimestamp
    @Column(name = "fecha_actualizacion", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaActualizacion;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega")
    private Bodega bodega;
}
