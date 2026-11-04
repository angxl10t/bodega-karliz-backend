package com.bodega.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class SolicitarRecuperacionDTO {

    @NotBlank(message = "El nombre de usuario o correo electrónico es obligatorio")
    @Size(min = 3, max = 150, message = "El identificador debe tener entre 3 y 150 caracteres")
    private String identificador;
}
