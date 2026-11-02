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

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RegistrarGarantiaDTO {

    @NotBlank(message = "El nombre de la persona es obligatorio")
    private String nombrePersona;

    private String telefono;

    private Long idCliente;

    @NotNull(message = "La cantidad de botellas es obligatoria")
    @Min(value = 1, message = "Debe registrar al menos 1 botella")
    private Integer cantidadBotellas;

    @NotNull(message = "El monto en garantía es obligatorio")
    @DecimalMin(value = "0.00", message = "El monto de garantía no puede ser negativo")
    private BigDecimal montoGarantia;

    private String tipoBotella;

    private String notas;
}
