package com.bodega.backend.dto;

import lombok.Data;
import java.time.OffsetDateTime;

@Data
public class BodegaDTO {
    private Long idBodega;
    private String nombreComercial;
    private String rucDni;
    private String direccion;
    private String telefono;
    private String logoUrl;
    private String colorPrimario;
    private String lemaComercial;
    private String plan;
    private Boolean estado;
    private OffsetDateTime fechaRegistro;
    private OffsetDateTime fechaVencimientoPlan;

    // Configuración Facturación Electrónica SUNAT
    private Boolean facturacionSunatActiva;
    private String sunatProveedor;
    private String sunatRucEmisor;
    private String sunatUsuarioSol;
    private String serieBoleta;
    private String serieFactura;
    private Long ultimoCorrelativoBoleta;
    private Long ultimoCorrelativoFactura;
}
