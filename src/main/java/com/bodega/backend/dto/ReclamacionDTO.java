package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReclamacionDTO {

    private Long idReclamacion;
    private String codigoReclamacion;
    private Long idBodega;
    private String nombreBodega;
    private String nombreReclamante;
    private String tipoDocumento;
    private String numeroDocumento;
    private String telefono;
    private String email;
    private String direccion;
    private String tipo;
    private String tipoBien;
    private BigDecimal montoReclamado;
    private String descripcionBien;
    private String detalleReclamacion;
    private String pedidoReclamante;
    private String estado;
    private String respuestaProveedor;
    private OffsetDateTime fechaReclamo;
    private OffsetDateTime fechaRespuesta;
    private int diasHabilesRestantes;
}
