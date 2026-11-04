package com.bodega.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class RestablecerPasswordDTO {

    @NotBlank(message = "El identificador (usuario o correo) es obligatorio")
    @Size(min = 3, max = 150)
    private String identificador;

    @NotBlank(message = "El código de verificación es obligatorio")
    @Pattern(regexp = "^[0-9]{6}$", message = "El código debe tener exactamente 6 dígitos numéricos")
    private String codigo;

    @NotBlank(message = "La nueva contraseña es obligatoria")
    @Size(min = 4, max = 72, message = "La nueva contraseña debe tener entre 4 y 72 caracteres")
    private String nuevaPassword;
}
