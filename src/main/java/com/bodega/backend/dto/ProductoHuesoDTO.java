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
public class ProductoHuesoDTO {
    private Long idProducto;
    private String nombre;
    private String codigo;
    private String categoria;
    private String imagenUrl;
    private BigDecimal stockActual;
    private BigDecimal precioCosto;
    private BigDecimal capitalInmovilizado;
    private int diasSinVentas;
    private String accionRecomendada;
}
