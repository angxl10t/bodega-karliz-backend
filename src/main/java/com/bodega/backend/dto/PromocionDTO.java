package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PromocionDTO {
    private Long idPromocion;
    private Long idBodega;
    private String titulo;
    private String descripcion;
    private String tipoPromocion; // PORCENTAJE, MONTO_FIJO, DOS_POR_UNO, COMBO_HUESO
    private String alcance;       // CATEGORIA, MARCA, PRODUCTO, COMBO
    private BigDecimal valorDescuento;
    private String categoriaObjetivo;
    private String marcaObjetivo;
    private Long idProductoPrincipal;
    private String nombreProductoPrincipal;
    private Long idProductoSecundario;
    private String nombreProductoSecundario;
    private BigDecimal precioCombo;
    private String badgeTexto;
    private String colorBadge;
    private LocalDate fechaInicio;
    private LocalDate fechaFin;
    private Boolean activo;
    private Boolean esSugerenciaHueso;
    private OffsetDateTime fechaCreacion;
}
