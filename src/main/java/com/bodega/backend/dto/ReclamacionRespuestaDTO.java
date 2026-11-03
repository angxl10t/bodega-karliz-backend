package com.bodega.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReclamacionRespuestaDTO {

    @NotBlank(message = "La respuesta al consumidor es obligatoria")
    private String respuestaProveedor;

    @Builder.Default
    private String nuevoEstado = "ATENDIDO"; // 'ATENDIDO', 'EN_PROCESO'
}
