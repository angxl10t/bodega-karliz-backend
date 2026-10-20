package com.bodega.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ProvisionarBodegaDTO {

    @NotBlank(message = "El nombre comercial es obligatorio")
    @Size(min = 2, max = 150, message = "El nombre comercial debe tener entre 2 y 150 caracteres")
    private String nombreComercial;

    private String rucDni;
    private String direccion;
    private String telefono;
    private String plan = "PRO";
    private Integer diasVigencia = 30;

    @NotBlank(message = "El usuario administrador es obligatorio")
    @Size(min = 3, max = 50, message = "El usuario debe tener entre 3 y 50 caracteres")
    private String adminUsername;

    @NotBlank(message = "La contraseña inicial es obligatoria")
    @Size(min = 4, max = 72, message = "La contraseña debe tener entre 4 y 72 caracteres")
    private String adminPassword;

    private String regimenTributario = "NUEVO_RUS";
    private String colorPrimario = "#2563EB";
    private String lemaComercial;
}
