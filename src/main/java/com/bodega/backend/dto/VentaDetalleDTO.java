package com.bodega.backend.dto;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.math.BigDecimal;

@Data
public class VentaDetalleDTO {
    private Long idDetalleVenta;

    @NotNull(message = "El producto es obligatorio")
    private Long idProducto;
    private String nombreProducto;

    @NotNull(message = "La cantidad es obligatoria")
    @DecimalMin(value = "0.001", message = "La cantidad debe ser mayor a 0")
    @DecimalMax(value = "99999.999", message = "La cantidad por ítem no puede exceder 99,999.999")
    private BigDecimal cantidad;

    // Estos campos no los envía el cliente, los devuelve el servidor calculados
    private BigDecimal precioUnitario; 
    private BigDecimal subtotal;
}
