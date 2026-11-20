package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VincularTerminalResponseDTO {
    private String terminalToken;
    private Long idBodega;
    private String nombreBodega;
    private String nombreTerminal;
    private Long idTerminal;
}
