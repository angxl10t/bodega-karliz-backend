package com.bodega.backend.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

@Data
public class FondoCajaDTO {
    private Long idFondoCaja;

    @NotNull(message = "El monto inicial de caja es obligatorio")
    @DecimalMin(value = "0.00", message = "El monto inicial no puede ser negativo")
    private BigDecimal montoInicial;

    private LocalDate fecha;
    private String usuarioRegistro;
    private OffsetDateTime fechaRegistro;
}
