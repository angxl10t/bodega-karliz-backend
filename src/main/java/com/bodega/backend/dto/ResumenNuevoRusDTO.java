package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * DTO para el Monitor Fiscal y Semáforo del Nuevo RUS de SUNAT (Ley N° 30877 - Ley del Bodeguero y D.L. 937).
 * Proporciona a la bodega de barrio un diagnóstico en tiempo real de sus topes mensuales (S/ 5,000 / S/ 8,000),
 * cuota mensual fija (S/ 20 / S/ 50), y estado de semáforo preventivo.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ResumenNuevoRusDTO {
    private Integer anio;
    private Integer mes;
    private String periodoNombre;
    private Boolean esNuevoRus;
    private String regimenTributario;

    // Métricas del mes calendario
    private BigDecimal totalVentasMes;
    private BigDecimal totalComprasMes;
    private BigDecimal montoDeterminante; // max(totalVentasMes, totalComprasMes)

    // Categorización oficial SUNAT Nuevo RUS
    // "CATEGORIA_1" (hasta S/ 5,000) | "CATEGORIA_2" (hasta S/ 8,000) | "EXCEDIDO" (> S/ 8,000)
    private String categoriaActual;
    private String categoriaNombre;
    private BigDecimal cuotaMensualEstimada; // S/ 20.00 o S/ 50.00 (0 si excedido)

    // Límites y saldos disponibles
    private BigDecimal limiteCat1; // 5000.00
    private BigDecimal limiteCat2; // 8000.00
    private BigDecimal restanteCat1;
    private BigDecimal restanteCat2;
    private Double porcentajeCat1;
    private Double porcentajeCat2;

    // Semáforo visual preventivo
    // "VERDE" (tranquilo) | "AMBAR" (próximo a saltar de categoría o tope) | "ROJO" (límite superado)
    private String estadoSemaforo;
    private String mensajeDiagnostico;
    private String advertencia;

    // Asistente tributario de pago SUNAT
    private String sugerenciaPagoSunat;
}
