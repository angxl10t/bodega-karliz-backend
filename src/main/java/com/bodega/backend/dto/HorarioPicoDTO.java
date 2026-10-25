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
public class HorarioPicoDTO {
    private int hora; // 0..23
    private String etiquetaHora; // e.g. "08:00 - 09:00"
    private int cantidadTickets;
    private BigDecimal totalVentas;
    private boolean esPico;
}
