package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ResumenGarantiasDTO {
    private BigDecimal totalDineroCustodia; // Dinero retenido actualmente en garantía
    private Integer botellasPendientes;     // Total de botellas aún en poder de los clientes
    private Long personasPendientes;       // Total de personas con garantías activas
    private BigDecimal totalDevueltoMes;    // Dinero entregado en devoluciones este mes
    private Integer botellasDevueltasMes;   // Botellas recuperadas este mes
}
