package com.bodega.backend.dto;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ConfiguracionSunatDTO {

    private Boolean facturacionSunatActiva;

    @Size(max = 50, message = "El proveedor no puede exceder 50 caracteres")
    private String sunatProveedor;

    @Pattern(regexp = "^$|^[0-9]{11}$", message = "El RUC emisor debe tener exactamente 11 dígitos numéricos")
    private String sunatRucEmisor;

    @Size(max = 50, message = "El usuario SOL no puede exceder 50 caracteres")
    private String sunatUsuarioSol;

    @Size(max = 255, message = "El token o clave SOL no puede exceder 255 caracteres")
    private String sunatTokenApi;

    @Size(max = 10, message = "La serie de boleta no puede exceder 10 caracteres")
    private String serieBoleta;

    @Size(max = 10, message = "La serie de factura no puede exceder 10 caracteres")
    private String serieFactura;
}
