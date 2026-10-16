package com.bodega.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.time.OffsetDateTime;

@Data
public class UsuarioDTO {

    private Long idUsuario;

    @NotBlank(message = "El nombre de usuario es obligatorio")
    @Size(min = 3, max = 50, message = "El nombre de usuario debe tener entre 3 y 50 caracteres")
    @Pattern(regexp = "^[a-zA-Z0-9._-]+$", message = "El nombre de usuario solo puede contener letras, números, puntos, guiones y guiones bajos")
    private String username;

    // Solo se recibe en peticiones (creación o reseteo). Jamás se expone en respuestas JSON hacia el frontend.
    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    @Size(min = 4, max = 72, message = "La contraseña o PIN debe tener entre 4 y 72 caracteres")
    private String password;

    @NotBlank(message = "El rol es obligatorio")
    @Pattern(regexp = "(?i)^(ADMIN|CAJERO)$", message = "El rol debe ser ADMIN o CAJERO")
    private String rol;

    private Boolean estado;

    private OffsetDateTime fechaCambioClave;

    private Long idBodega;
    private String nombreBodega;
    private String planBodega;
}
