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
public class SugerenciaPrecioDTO {
    private Long idSugerencia;
    private Long idBodega;
    private String nombreBodega;
    private Long idProducto;
    private String codigoBarras;
    private String nombreActual;
    private String nombreSugerido;
    private String marcaActual;
    private String marcaSugerida;
    private BigDecimal precioVentaActual;
    private BigDecimal precioVentaSugerido;
    private BigDecimal precioCostoActual;
    private BigDecimal precioCostoSugerido;
    private String imagenUrl;
    private String motivo;
    private String estado;
    private OffsetDateTime fechaCreacion;
    private OffsetDateTime fechaResolucion;
    private String usuarioResolucion;
}
