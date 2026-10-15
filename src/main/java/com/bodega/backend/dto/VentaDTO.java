package com.bodega.backend.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.Data;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

@Data
public class VentaDTO {
    private Long idVenta;

    @Size(max = 20, message = "El documento del cliente no puede exceder los 20 caracteres")
    private String clienteDocumento;

    @Size(max = 150, message = "El nombre del cliente no puede exceder los 150 caracteres")
    private String clienteNombre;

    @Size(max = 50, message = "El método de pago no puede exceder los 50 caracteres")
    private String metodoPago;

    private BigDecimal total;
    private OffsetDateTime fechaVenta;
    private String usuarioRegistro; // Usuario que registró la venta (Auditoría)

    @NotEmpty(message = "La venta debe tener al menos un producto")
    @Valid
    private List<VentaDetalleDTO> detalles;
}
