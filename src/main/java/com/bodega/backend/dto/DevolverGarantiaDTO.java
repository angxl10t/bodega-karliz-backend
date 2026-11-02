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
public class DevolverGarantiaDTO {
    /**
     * Cantidad de botellas que devuelve el cliente.
     * Si es null o menor/igual a 0, se asume la totalidad de botellas pendientes.
     */
    private Integer cantidadDevolver;

    /**
     * Monto en dinero entregado de vuelta al cliente.
     * Si es null o menor/igual a 0, se calcula proporcionalmente o el total restante.
     */
    private BigDecimal montoEntregado;

    /**
     * Nota u observación opcional de la devolución.
     */
    private String notas;
}
