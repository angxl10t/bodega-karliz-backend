package com.bodega.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ActualizarBodegaDTO {

    @NotBlank(message = "El nombre de la bodega o negocio es obligatorio")
    @Size(min = 3, max = 150, message = "El nombre debe tener entre 3 y 150 caracteres")
    private String nombreComercial;

    @Pattern(regexp = "^$|^(?:[0-9]{8}|[0-9]{11})$", message = "El documento debe ser un DNI de 8 dígitos o RUC de 11 dígitos")
    private String rucDni;

    @Size(max = 255, message = "La dirección no puede exceder 255 caracteres")
    private String direccion;

    @Size(max = 30, message = "El teléfono no puede exceder 30 caracteres")
    private String telefono;

    @Size(max = 255, message = "El lema comercial no puede exceder 255 caracteres")
    private String lemaComercial;

    @Size(max = 20, message = "El código de color no puede exceder 20 caracteres")
    private String colorPrimario;

    @Size(max = 500, message = "La URL del logo no puede exceder 500 caracteres")
    private String logoUrl;
}
