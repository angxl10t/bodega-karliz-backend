package com.bodega.backend.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
public class ClienteDTO {
    private Long idCliente;
    private Long idBodega;

    @Size(max = 20, message = "El documento no puede exceder 20 caracteres")
    private String documento;

    @NotBlank(message = "El nombre completo del cliente es obligatorio")
    @Size(max = 150, message = "El nombre no puede exceder 150 caracteres")
    private String nombreCompleto;

    @Size(max = 30, message = "El teléfono no puede exceder 30 caracteres")
    private String telefono;

    @Size(max = 255, message = "La dirección no puede exceder 255 caracteres")
    private String direccion;

    @DecimalMin(value = "0.00", message = "El límite de crédito no puede ser negativo")
    private BigDecimal limiteCredito;

    private BigDecimal saldoDeudor;
    private BigDecimal creditoDisponible;

    private String notas;
    private Boolean estado;
    private OffsetDateTime fechaRegistro;
    private OffsetDateTime fechaUltimoPago;
}
