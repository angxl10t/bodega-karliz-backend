package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BoletaConsolidadaDTO {
    private Long idBoletaConsolidada;
    private Long idBodega;
    private LocalDate fechaEmision;
    private BigDecimal montoTotal;
    private Integer cantidadOperaciones;
    private String serieCorrelativo;
    private String tipoEmision;
    private String observaciones;
    private String usuarioRegistro;
    private OffsetDateTime fechaRegistro;
}
