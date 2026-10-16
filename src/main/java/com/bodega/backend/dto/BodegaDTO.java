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
    private String plan;
    private Boolean estado;
    private OffsetDateTime fechaRegistro;
    private OffsetDateTime fechaVencimientoPlan;
}
