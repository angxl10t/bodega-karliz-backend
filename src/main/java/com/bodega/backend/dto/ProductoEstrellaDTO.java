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
public class ProductoEstrellaDTO {
    private Long idProducto;
    private String nombre;
    private String codigo;
    private String categoria;
    private String imagenUrl;
    private BigDecimal unidadesVendidas;
    private BigDecimal totalVentas;
    private BigDecimal costoTotal;
    private BigDecimal margenBrutoSoles;
    private BigDecimal porcentajeMargen;
}
