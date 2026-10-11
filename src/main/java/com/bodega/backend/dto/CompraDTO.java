package com.bodega.backend.dto;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

@Data
public class CompraDTO {
    private Long idCompra;
    
    @NotNull(message = "El proveedor es obligatorio")
    private Long idProveedor;
    private String razonSocialProveedor; // Solo lectura

    private String comprobante;
    private BigDecimal total;
    private OffsetDateTime fechaCompra;

    @NotEmpty(message = "La compra debe tener al menos un detalle")
    @Valid
    private List<CompraDetalleDTO> detalles;
}
