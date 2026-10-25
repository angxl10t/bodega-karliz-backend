package com.bodega.backend.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.math.BigDecimal;

@Data
public class RegistrarAbonoDTO {
    @NotNull(message = "El monto del abono es obligatorio")
    @DecimalMin(value = "0.10", message = "El monto mínimo a abonar es S/ 0.10")
    private BigDecimal monto;

    private String metodoPago = "Efectivo";
    private String notas;
}
