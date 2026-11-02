package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * DTO para sugerencias inteligentes de combinaciones de productos Hueso (dormidos)
 * con productos Estrella (alta rotación) para destrabar capital inmovilizado.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SugerenciaComboHuesoDTO {
    // Producto Hueso (estancado)
    private Long idProductoHueso;
    private String nombreHueso;
    private String categoriaHueso;
    private String imagenUrlHueso;
    private BigDecimal stockHueso;
    private BigDecimal costoHueso;
    private BigDecimal precioRegularHueso;
    private BigDecimal capitalInmovilizado;

    // Producto Estrella (tractor de ventas)
    private Long idProductoEstrella;
    private String nombreEstrella;
    private String categoriaEstrella;
    private String imagenUrlEstrella;
    private BigDecimal precioRegularEstrella;

    // Propuesta de combo
    private String tituloSugerido;
    private String descripcionSugerida;
    private BigDecimal precioRegularTotal;
    private BigDecimal precioComboSugerido;
    private BigDecimal ahorroCliente;
    private BigDecimal porcentajeDescuentoSugerido;
    private String razonEstrategica;
    private String badgeSugerido;
}
