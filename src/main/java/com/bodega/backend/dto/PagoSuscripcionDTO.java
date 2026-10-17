package com.bodega.backend.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
public class PagoSuscripcionDTO {
    private Long idPago;
    private Long idBodega;
    private String nombreBodega;
    private String codigoOperacion;
    private String billetera;
    private String plan;
    private BigDecimal monto;
    private OffsetDateTime fechaPago;
    private String usuarioRegistro;
    private String estado;
}
