package com.bodega.backend.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RegistrarBoletaConsolidadaDTO {
    @NotNull(message = "La fecha de emisión es obligatoria")
    private LocalDate fecha;

    @NotNull(message = "El monto total es obligatorio")
    @DecimalMin(value = "0.01", message = "El monto total debe ser mayor a cero")
    private BigDecimal montoTotal;

    @NotNull(message = "La cantidad de operaciones es obligatoria")
    @Min(value = 1, message = "Debe haber al menos 1 operación consolidada")
    private Integer cantidadOperaciones;

    @NotBlank(message = "La serie y correlativo de la boleta es obligatoria")
    private String serieCorrelativo;

    private String tipoEmision; // "TALONARIO_FISICO" | "DIGITAL_CAJAYA"
    private String observaciones;
}
