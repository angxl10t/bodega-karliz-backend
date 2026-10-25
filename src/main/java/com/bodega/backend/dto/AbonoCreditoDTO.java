package com.bodega.backend.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
public class AbonoCreditoDTO {
    private Long idAbono;
    private Long idCliente;
    private String nombreCliente;
    private BigDecimal monto;
    private String metodoPago;
    private BigDecimal saldoAnterior;
    private BigDecimal saldoRestante;
    private String comprobanteNumero;
    private String notas;
    private String usuarioRegistro;
    private OffsetDateTime fechaAbono;
}
