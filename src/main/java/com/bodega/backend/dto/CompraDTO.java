package com.bodega.backend.dto;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
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

    @Size(max = 50, message = "El número de comprobante no puede exceder los 50 caracteres")
    private String comprobante;
    private BigDecimal total;
    private OffsetDateTime fechaCompra;
    private String usuarioRegistro;

    @NotEmpty(message = "La compra debe tener al menos un detalle")
    @Size(max = 100, message = "La compra no puede contener más de 100 productos diferentes")
    @Valid
    private List<CompraDetalleDTO> detalles;
}
