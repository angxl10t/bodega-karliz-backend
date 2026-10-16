package com.bodega.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class RegistroBodegaDTO {

    @NotBlank(message = "El nombre de la bodega o negocio es obligatorio")
    @Size(min = 3, max = 150, message = "El nombre de la bodega debe tener entre 3 y 150 caracteres")
    private String nombreComercial;

    @Pattern(regexp = "^$|^(?:[0-9]{8}|[0-9]{11})$", message = "El documento debe ser un DNI de 8 dígitos o RUC de 11 dígitos")
    private String rucDni;

    @Size(max = 255)
    private String direccion;

    @Size(max = 30)
    private String telefono;

    @Size(max = 20)
    private String colorPrimario;

    @Size(max = 255)
    private String lemaComercial;

    @NotBlank(message = "El nombre de usuario administrador es obligatorio")
    @Size(min = 3, max = 50, message = "El nombre de usuario debe tener entre 3 y 50 caracteres")
    @Pattern(regexp = "^[a-zA-Z0-9._-]+$", message = "El usuario solo puede contener letras, números, puntos y guiones")
    private String username;

    @NotBlank(message = "La contraseña es obligatoria")
    @Size(min = 8, max = 72, message = "La contraseña debe tener entre 8 y 72 caracteres")
    private String password;
}
