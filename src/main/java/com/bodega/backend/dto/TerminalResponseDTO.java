package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TerminalResponseDTO {
    private Long idTerminal;
    private String nombre;
    private String deviceModel;
    private OffsetDateTime fechaVinculacion;
    private OffsetDateTime ultimoAcceso;
    private Boolean estado;
}
