package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GarantiaBotellaDTO {
    private Long idGarantia;
    private Long idBodega;
    private Long idCliente;
    private String nombrePersona;
    private String telefono;
    private Integer cantidadBotellas;
    private BigDecimal montoGarantia;
    private String tipoBotella;
    private String notas;
    private String estado;
    private Integer botellasDevueltas;
    private BigDecimal montoDevuelto;
    private Integer botellasRestantes;
    private BigDecimal montoRestante;
    private OffsetDateTime fechaRegistro;
    private OffsetDateTime fechaDevolucion;
    private String usuarioRegistro;
}
