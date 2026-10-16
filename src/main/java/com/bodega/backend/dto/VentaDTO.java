package com.bodega.backend.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
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

    @Pattern(regexp = "(?i)^(Efectivo|Yape|Plin|Tarjeta)$", message = "El método de pago debe ser: Efectivo, Yape, Plin o Tarjeta")
    @Size(max = 50, message = "El método de pago no puede exceder los 50 caracteres")
    private String metodoPago;

    private BigDecimal total;
    private OffsetDateTime fechaVenta;
    private String usuarioRegistro; // Usuario que registró la venta (Auditoría)

    // Datos de Soft-Delete y Trazabilidad de Anulación
    private String estado;
    private OffsetDateTime fechaAnulacion;
    private String usuarioAnulacion;
    private String motivoAnulacion;

    // Facturación y Comprobantes SUNAT
    private String tipoComprobante;
    private String serieCorrelativo;
    private String estadoSunat;

    @NotEmpty(message = "La venta debe tener al menos un producto")
    @Size(max = 100, message = "La venta no puede contener más de 100 productos diferentes")
    @Valid
    private List<VentaDetalleDTO> detalles;
}
