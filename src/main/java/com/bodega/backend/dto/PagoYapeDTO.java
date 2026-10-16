package com.bodega.backend.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class PagoYapeDTO {

    @NotBlank(message = "El código o número de operación es obligatorio")
    @Size(min = 4, max = 30, message = "El código de operación debe tener entre 4 y 30 caracteres")
    private String codigoOperacion;

    @NotBlank(message = "El plan es obligatorio")
    @Pattern(regexp = "(?i)^(BASICO|PRO)$", message = "El plan debe ser BASICO o PRO")
    private String plan;

    @NotNull(message = "El monto es obligatorio")
    @DecimalMin(value = "1.00", message = "El monto debe ser mayor a 0")
    private BigDecimal monto;

    @NotBlank(message = "La billetera es obligatoria")
    @Pattern(regexp = "(?i)^(YAPE|PLIN|TRANSFERENCIA)$", message = "La billetera debe ser YAPE, PLIN o TRANSFERENCIA")
    private String billetera;
}
