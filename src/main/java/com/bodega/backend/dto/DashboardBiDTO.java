package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DashboardBiDTO {
    private int diasAnalizados;

    // Métricas de Rentabilidad Real
    private BigDecimal totalVentas;
    private BigDecimal totalCostos;
    private BigDecimal margenBrutoSoles;
    private BigDecimal porcentajeMargenBruto;

    // Tickets Promedio
    private BigDecimal ticketPromedioHoy;
    private BigDecimal ticketPromedioSemanal;
    private BigDecimal ticketPromedioPeriodo;
    private int cantidadVentasHoy;
    private int cantidadVentasPeriodo;

    // Reporte de Rotación
    @Builder.Default
    private List<ProductoEstrellaDTO> productosEstrella = new ArrayList<>();
    @Builder.Default
    private List<ProductoHuesoDTO> productosHueso = new ArrayList<>();
    private BigDecimal totalCapitalInmovilizado;
    private int totalProductosHueso;

    // Mapa de Calor de Horarios Pico
    @Builder.Default
    private List<HorarioPicoDTO> distribucionHoraria = new ArrayList<>();
    private String horaPicoMaxima;
    private String recomendacionTurnos;
    private String horaValleMinima;
}
