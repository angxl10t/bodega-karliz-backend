package com.bodega.backend.dto;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ConfiguracionSunatDTO {

    private Boolean facturacionSunatActiva;

    @Pattern(regexp = "^$|^(NUEVO_RUS|RER|MYPE_TRIBUTARIO|REGIMEN_GENERAL)$", message = "El régimen tributario debe ser: NUEVO_RUS, RER, MYPE_TRIBUTARIO o REGIMEN_GENERAL")
    private String regimenTributario;

    @Size(max = 50, message = "El proveedor no puede exceder 50 caracteres")
    private String sunatProveedor;

    @Pattern(regexp = "^$|^[0-9]{11}$", message = "El RUC emisor debe tener exactamente 11 dígitos numéricos")
    private String sunatRucEmisor;

    @Size(max = 50, message = "El usuario SOL no puede exceder 50 caracteres")
    private String sunatUsuarioSol;

    @Size(max = 255, message = "El token o clave SOL no puede exceder 255 caracteres")
    private String sunatTokenApi;

    @Pattern(regexp = "^$|^[B|b][A-Za-z0-9]{3}$", message = "La serie de boleta debe tener 4 caracteres e iniciar con 'B' (ej: B001)")
    private String serieBoleta;

    @Pattern(regexp = "^$|^[F|f][A-Za-z0-9]{3}$", message = "La serie de factura debe tener 4 caracteres e iniciar con 'F' (ej: F001)")
    private String serieFactura;
}
