package com.bodega.backend.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
public class MovimientoInventarioDTO {
    private Long idMovimiento;
    private Long idProducto;
    private String nombreProducto;
    private String tipoMovimiento;
    private BigDecimal cantidad;
    private String motivo;
    private OffsetDateTime fechaMovimiento;
}
