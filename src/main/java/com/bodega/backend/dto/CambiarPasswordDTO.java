package com.bodega.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class CambiarPasswordDTO {

    @NotBlank(message = "La contraseña actual es obligatoria")
    @Size(max = 72, message = "La contraseña actual no puede exceder 72 caracteres")
    private String passwordActual;

    @NotBlank(message = "La nueva contraseña es obligatoria")
    @Size(min = 8, max = 72, message = "La nueva contraseña debe tener entre 8 y 72 caracteres")
    private String nuevaPassword;
}
