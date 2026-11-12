package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "catalogo_starter_pack_global")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StarterPackPreset {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_preset")
    private Long idPreset;

    @Column(name = "codigo_barras", nullable = false, unique = true, length = 50)
    private String codigoBarras;

    @Column(nullable = false, length = 255)
    private String nombre;

    @Column(length = 100)
    private String marca;

    @Column(nullable = false, length = 100)
    private String categoria;

    @Column(name = "precio_venta", nullable = false, precision = 10, scale = 2)
    @Builder.Default
    private BigDecimal precioVenta = BigDecimal.ZERO;

    @Column(name = "precio_costo", nullable = false, precision = 10, scale = 2)
    @Builder.Default
    private BigDecimal precioCosto = BigDecimal.ZERO;

    @Column(name = "imagen_url", length = 500)
    private String imagenUrl;

    @Column(nullable = false)
    @Builder.Default
    private Boolean activo = true;

    @Column(name = "fecha_creacion")
    private OffsetDateTime fechaCreacion;

    @Column(name = "fecha_modificacion")
    private OffsetDateTime fechaModificacion;

    @PrePersist
    public void prePersist() {
        if (fechaCreacion == null) fechaCreacion = OffsetDateTime.now();
        if (fechaModificacion == null) fechaModificacion = OffsetDateTime.now();
        if (activo == null) activo = true;
    }

    @PreUpdate
    public void preUpdate() {
        fechaModificacion = OffsetDateTime.now();
    }
}
