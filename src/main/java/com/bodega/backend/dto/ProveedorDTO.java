package com.bodega.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ProveedorDTO {
    private Long idProveedor;

    @NotBlank(message = "El RUC o DNI es obligatorio")
    @Pattern(regexp = "^[0-9]{8}$|^[0-9]{11}$", message = "El documento debe ser un DNI (8 dígitos) o RUC (11 dígitos) numérico")
    @Size(min = 8, max = 20, message = "El RUC debe tener entre 8 y 20 caracteres")
    private String ruc;

    @NotBlank(message = "La razón social es obligatoria")
    @Size(max = 255)
    private String razonSocial;

    @Size(max = 255)
    private String direccion;

    @Size(max = 20)
    private String telefono;

    private Boolean estado;
}
