package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CajeroTerminalDTO {
    private Long idUsuario;
    private String nombreCompleto;
    private String username;
    private String iniciales;
    private String rol;
}
