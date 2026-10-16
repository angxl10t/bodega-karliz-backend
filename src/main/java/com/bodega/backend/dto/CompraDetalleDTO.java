package com.bodega.backend.dto;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.math.BigDecimal;

@Data
public class CompraDetalleDTO {
    private Long idDetalleCompra;

    @NotNull(message = "El producto es obligatorio")
    private Long idProducto;
    private String nombreProducto; // Solo lectura

    @NotNull(message = "La cantidad es obligatoria")
    @DecimalMin(value = "0.001", message = "La cantidad debe ser mayor a 0")
    @DecimalMax(value = "99999.999", message = "La cantidad por ítem no puede exceder 99,999.999")
    private BigDecimal cantidad;

    @NotNull(message = "El precio unitario es obligatorio")
    @DecimalMin(value = "0.01", message = "El precio debe ser mayor a 0")
    @DecimalMax(value = "999999.99", message = "El precio unitario no puede exceder 999,999.99")
    private BigDecimal precioUnitario;

    private BigDecimal subtotal; // Solo lectura (lo calcula el backend por seguridad)
}
