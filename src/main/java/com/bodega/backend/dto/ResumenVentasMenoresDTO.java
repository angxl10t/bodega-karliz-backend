package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

/**
 * DTO que resume las ventas del día menores o iguales a S/ 5.00 emitidas en ticket
 * para orientar al bodeguero en la emisión de su Boleta Consolidada Diaria (Nuevo RUS).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ResumenVentasMenoresDTO {
    private LocalDate fecha;
    private boolean yaRegistrada;
    private Long idBoletaConsolidada;
    private String serieCorrelativo;
    private String tipoEmision;
    private BigDecimal montoRegistrado;
    private Integer cantidadOperacionesRegistradas;
    private String observaciones;
    private String usuarioRegistro;
    private OffsetDateTime fechaRegistro;

    // Sugerencia calculada por el sistema
    private BigDecimal montoSugerido;
    private Integer cantidadOperacionesSugeridas;
    private String baseLegal;
}
