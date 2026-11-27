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
public class NotificacionDTO {
    private Long idNotificacion;
    private Long idBodega;
    private Long idUsuarioDestinatario;
    private String rolDestinatario;
    private String tipo;
    private String titulo;
    private String mensaje;
    private String metadataJson;
    private String prioridad;
    private Boolean leido;
    private OffsetDateTime fechaCreacion;
    private OffsetDateTime fechaLeido;
}
