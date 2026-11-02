package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

/**
 * Entidad de Promociones y Descuentos Estratégicos (Exclusivo Plan PRO).
 * Permite a los administradores de minimarkets y bodegas configurar:
 * - Descuentos por categoría (ej. Bebidas -15%)
 * - Descuentos por marca (ej. Pepsi -10%)
 * - Descuentos por producto individual o 2x1
 * - Combos estratégicos para liquidar productos "Hueso" emparejados con estrellas
 */
@Data
@Entity
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "promociones",
    indexes = {
        @Index(name = "idx_promociones_bodega_activo", columnList = "id_bodega, activo"),
        @Index(name = "idx_promociones_alcance", columnList = "alcance")
    }
)
public class Promocion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_promocion")
    private Long idPromocion;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_bodega", nullable = false)
    private Bodega bodega;

    @Column(nullable = false, length = 150)
    private String titulo;

    @Column(length = 255)
    private String descripcion;

    /**
     * Tipo: PORCENTAJE, MONTO_FIJO, DOS_POR_UNO, COMBO_HUESO
     */
    @Column(name = "tipo_promocion", nullable = false, length = 40)
    private String tipoPromocion;

    /**
     * Alcance: CATEGORIA, MARCA, PRODUCTO, COMBO
     */
    @Column(nullable = false, length = 40)
    private String alcance;

    /**
     * Valor del descuento (% o S/ de rebaja)
     */
    @Column(name = "valor_descuento", precision = 12, scale = 2)
    private BigDecimal valorDescuento;

    @Column(name = "categoria_objetivo", length = 100)
    private String categoriaObjetivo;

    @Column(name = "marca_objetivo", length = 100)
    private String marcaObjetivo;

    @Column(name = "id_producto_principal")
    private Long idProductoPrincipal;

    @Column(name = "nombre_producto_principal", length = 150)
    private String nombreProductoPrincipal;

    @Column(name = "id_producto_secundario")
    private Long idProductoSecundario;

    @Column(name = "nombre_producto_secundario", length = 150)
    private String nombreProductoSecundario;

    @Column(name = "precio_combo", precision = 12, scale = 2)
    private BigDecimal precioCombo;

    @Column(name = "badge_texto", length = 40)
    private String badgeTexto;

    @Column(name = "color_badge", length = 20)
    private String colorBadge;

    @Column(name = "fecha_inicio")
    private LocalDate fechaInicio;

    @Column(name = "fecha_fin")
    private LocalDate fechaFin;

    @Builder.Default
    @Column(nullable = false)
    private Boolean activo = true;

    @Builder.Default
    @Column(name = "es_sugerencia_hueso", nullable = false)
    private Boolean esSugerenciaHueso = false;

    @CreationTimestamp
    @Column(name = "fecha_creacion", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaCreacion;

    @UpdateTimestamp
    @Column(name = "fecha_actualizacion", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaActualizacion;
}
