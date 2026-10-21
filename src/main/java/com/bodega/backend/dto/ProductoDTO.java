package com.bodega.backend.dto;

import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class ProductoDTO {
    private Long idProducto;

    @NotNull(message = "El ID de la categoría es obligatorio")
    private Long idCategoria;

    private String nombreCategoria; // Nos servirá para mostrarlo bonito en la app móvil y web

    @Size(max = 50, message = "El código no puede exceder 50 caracteres")
    private String codigo;

    @Size(max = 100, message = "El código de barras no puede exceder 100 caracteres")
    private String codigoBarras;

    @NotBlank(message = "El nombre del producto es obligatorio")
    @Size(max = 150)
    private String nombre;

    @Size(max = 100)
    private String marca;

    @NotNull(message = "El precio de venta es obligatorio")
    @DecimalMin(value = "0.0", inclusive = false, message = "El precio debe ser mayor a 0")
    @DecimalMax(value = "999999.99", message = "El precio de venta no puede exceder 999,999.99")
    private BigDecimal precioVenta;

    @DecimalMin(value = "0.0", message = "El stock no puede ser negativo")
    @DecimalMax(value = "999999.999", message = "El stock no puede exceder 999,999.999")
    private BigDecimal stockActual;

    @NotNull(message = "El stock mínimo es obligatorio")
    @DecimalMin(value = "0.0", message = "El stock mínimo no puede ser negativo")
    @DecimalMax(value = "999999.999", message = "El stock mínimo no puede exceder 999,999.999")
    private BigDecimal stockMinimo;

    private Boolean controlaVencimiento;
    private String imagenUrl;
    private Boolean estado;
}
