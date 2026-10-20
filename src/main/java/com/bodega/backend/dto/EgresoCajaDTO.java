package com.bodega.backend.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
public class EgresoCajaDTO {
    private Long idEgreso;

    @NotNull(message = "El monto del egreso es obligatorio")
    @DecimalMin(value = "0.01", message = "El monto del egreso debe ser mayor a cero")
    private BigDecimal monto;

    @NotBlank(message = "El motivo del egreso es obligatorio")
    @Size(max = 255, message = "El motivo no puede exceder los 255 caracteres")
    private String motivo;

    @Size(max = 50, message = "La categoría de gasto no puede exceder los 50 caracteres")
    private String categoriaGasto;

    private OffsetDateTime fechaEgreso;
    private String usuarioRegistro;

    private Boolean estado;
    private String usuarioAnulacion;
    private String motivoAnulacion;
    private OffsetDateTime fechaAnulacion;
}
