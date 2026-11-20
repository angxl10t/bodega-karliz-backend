package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SolicitudCodigoVinculacionResponseDTO {
    private String codigo;
    private long expiraEnSegundos;
    private String qrPayload;
    private String nombreBodega;
    private Long idBodega;
}
