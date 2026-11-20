package com.bodega.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class VincularTerminalRequestDTO {

    @NotBlank(message = "El código de emparejamiento es obligatorio")
    private String codigoEmparejamiento;

    private String nombreTerminal;

    private String deviceModel;
}
