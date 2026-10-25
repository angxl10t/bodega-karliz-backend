package com.bodega.backend.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.util.List;

@Data
public class EstadoCuentaClienteDTO {
    private ClienteDTO cliente;
    private BigDecimal totalVentasCredito;
    private BigDecimal totalAbonosRealizados;
    private List<VentaDTO> comprasCreditoRecientes;
    private List<AbonoCreditoDTO> abonosRecientes;
}
