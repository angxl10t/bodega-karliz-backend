package com.bodega.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class LoginCajeroPinDTO {

    private Long idBodega;

    private String codigoTienda;

    private Long idUsuario;

    private String terminalToken;

    @NotBlank(message = "El PIN de cajero es obligatorio")
    @Pattern(regexp = "^[0-9]{4,6}$", message = "El PIN debe tener entre 4 y 6 dígitos numéricos")
    private String pin;
}
