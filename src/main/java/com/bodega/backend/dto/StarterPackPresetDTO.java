package com.bodega.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.math.BigDecimal;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StarterPackPresetDTO {

    private Long idPreset;

    @NotBlank(message = "El código de barras es obligatorio")
    private String codigoBarras;

    @NotBlank(message = "El nombre del producto es obligatorio")
    private String nombre;

    private String marca;

    @NotBlank(message = "La categoría es obligatoria")
    private String categoria;

    @NotNull(message = "El precio de venta sugerido es obligatorio")
    private BigDecimal precioVenta;

    private BigDecimal precioCosto;

    private String imagenUrl;

    private Boolean activo;
}
