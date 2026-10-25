package com.bodega.backend.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class ResumenCreditosDTO {
    private long totalClientes;
    private long clientesConDeuda;
    private BigDecimal totalSaldoDeudor;
    private BigDecimal totalAbonosMes;
}
