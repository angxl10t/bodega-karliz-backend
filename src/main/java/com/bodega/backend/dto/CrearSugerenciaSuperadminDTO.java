package com.bodega.backend.dto;

import jakarta.validation.constraints.DecimalMin;
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
public class CrearSugerenciaSuperadminDTO {

    @NotBlank(message = "El código de barras es obligatorio para localizar el producto.")
    private String codigoBarras;

    @NotNull(message = "El precio de venta sugerido es obligatorio.")
    @DecimalMin(value = "0.01", message = "El precio de venta sugerido debe ser mayor a 0.")
    private BigDecimal precioVentaSugerido;

    private BigDecimal precioCostoSugerido;

    private String nombreSugerido;

    private String marcaSugerida;

    private String motivo;

    private Long idBodegaEspecifica;
}
