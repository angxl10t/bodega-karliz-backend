package com.bodega.backend.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
public class CierreCajaDTO {
    private BigDecimal totalVentas = BigDecimal.ZERO;
    private BigDecimal totalEfectivo = BigDecimal.ZERO;
    private BigDecimal totalYape = BigDecimal.ZERO;
    private BigDecimal totalPlin = BigDecimal.ZERO;
    private BigDecimal totalTarjeta = BigDecimal.ZERO;
    private Integer cantidadVentas = 0;
    private OffsetDateTime fecha;
}
