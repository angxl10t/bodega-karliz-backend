package com.bodega.backend.dto;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import lombok.Data;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

@Data
public class VentaDTO {
    private Long idVenta;
    private String clienteDocumento;
    private String clienteNombre;
    private String metodoPago;
    private BigDecimal total;
    private OffsetDateTime fechaVenta;

    @NotEmpty(message = "La venta debe tener al menos un producto")
    @Valid
    private List<VentaDetalleDTO> detalles;
}
