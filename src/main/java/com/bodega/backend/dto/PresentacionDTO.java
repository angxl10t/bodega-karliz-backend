package com.bodega.backend.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;
import java.math.BigDecimal;

@Data
public class PresentacionDTO {
    private Long idPresentacion;

    @NotNull(message = "El ID del producto es obligatorio")
    private Long idProducto;

    private String nombreProducto; // Solo lectura para la respuesta de la API

    @NotBlank(message = "El nombre de la presentación es obligatorio")
    @Size(max = 100)
    private String nombre; // Ej. "Caja x 6"

    @NotNull(message = "El factor de conversión es obligatorio")
    @DecimalMin(value = "0.001", message = "El factor de conversión debe ser mayor a 0")
    private BigDecimal factorConversion;

    private Boolean estado;
}
