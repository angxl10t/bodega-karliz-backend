package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;

import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "bodegas", indexes = {
    @Index(name = "idx_bodegas_estado", columnList = "estado"),
    @Index(name = "idx_bodegas_plan", columnList = "plan")
})
public class Bodega {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_bodega")
    private Long idBodega;

    @Column(name = "nombre_comercial", nullable = false, length = 150)
    private String nombreComercial;

    @Column(name = "ruc_dni", length = 20)
    private String rucDni;

    @Column(length = 255)
    private String direccion;

    @Column(length = 30)
    private String telefono;

    @Column(name = "logo_url", length = 500)
    private String logoUrl;

    @Column(name = "color_primario", length = 20)
    private String colorPrimario = "#2563EB";

    @Column(name = "lema_comercial", length = 255)
    private String lemaComercial;

    // 'BASICO' (1 admin, sin cajeros) | 'PRO' (admin + cajeros con PIN ilimitados) | 'CORPORATIVO'
    @Column(nullable = false, length = 30)
    private String plan = "BASICO";

    @Column(nullable = false)
    private Boolean estado = true;

    @CreationTimestamp
    @Column(name = "fecha_registro", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaRegistro;

    @Column(name = "fecha_vencimiento_plan", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaVencimientoPlan;
}
