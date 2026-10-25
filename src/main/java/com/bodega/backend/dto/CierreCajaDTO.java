package com.bodega.backend.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Data
public class CierreCajaDTO {
    private BigDecimal totalVentas = BigDecimal.ZERO;
    private BigDecimal totalEfectivo = BigDecimal.ZERO;
    private BigDecimal totalEfectivoRecibido = BigDecimal.ZERO;
    private BigDecimal totalVueltoEntregado = BigDecimal.ZERO;
    private BigDecimal totalYape = BigDecimal.ZERO;
    private BigDecimal totalPlin = BigDecimal.ZERO;
    private BigDecimal totalTarjeta = BigDecimal.ZERO;
    private BigDecimal totalCredito = BigDecimal.ZERO;
    private Integer cantidadVentas = 0;
    private OffsetDateTime fecha;

    // Arqueo y Control de Turno
    private BigDecimal fondoInicial = BigDecimal.ZERO;
    private BigDecimal totalEgresos = BigDecimal.ZERO;
    private BigDecimal totalEfectivoEsperado = BigDecimal.ZERO;
    private List<EgresoCajaDTO> egresos = new ArrayList<>();

    // Cobranza de Fiados / Deudas de Clientes (Abonos)
    private BigDecimal totalAbonosCobrados = BigDecimal.ZERO;
    private BigDecimal totalAbonosEfectivo = BigDecimal.ZERO;
    private BigDecimal totalAbonosDigitales = BigDecimal.ZERO;
    private Integer cantidadAbonos = 0;
}
