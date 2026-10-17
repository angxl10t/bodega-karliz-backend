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

    // Régimen Tributario SUNAT: 'NUEVO_RUS' (solo Boleta/Ticket) | 'RER' | 'MYPE_TRIBUTARIO' | 'REGIMEN_GENERAL' (Boleta y Factura)
    @Column(name = "regimen_tributario", length = 30)
    private String regimenTributario = "NUEVO_RUS";

    // Módulo Adicional: Facturación Electrónica SUNAT (Activación exclusiva por ADMIN)
    @Column(name = "facturacion_sunat_activa")
    private Boolean facturacionSunatActiva = false;

    @Column(name = "sunat_proveedor", length = 50)
    private String sunatProveedor = "SUNAT_DIRECTO_GRATUITO";

    @Column(name = "sunat_ruc_emisor", length = 11)
    private String sunatRucEmisor;

    @Column(name = "sunat_usuario_sol", length = 50)
    private String sunatUsuarioSol;

    @Column(name = "sunat_token_api", length = 255)
    private String sunatTokenApi;

    @Column(name = "serie_boleta", length = 10)
    private String serieBoleta = "B001";

    @Column(name = "serie_factura", length = 10)
    private String serieFactura = "F001";

    @Column(name = "ultimo_correlativo_boleta")
    private Long ultimoCorrelativoBoleta = 0L;

    @Column(name = "ultimo_correlativo_factura")
    private Long ultimoCorrelativoFactura = 0L;
}
