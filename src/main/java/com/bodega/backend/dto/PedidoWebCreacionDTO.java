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
public class PedidoWebCreacionDTO {
    private String idPedido;
    private String codigoPedido;
    private String nombreCliente;
    private String telefonoCliente;
    private String notas;
    private BigDecimal total;
    private BigDecimal ahorroPromociones;
    private Boolean incluyeRetornables;
    @Builder.Default
    private List<PedidoWebDetalleCreacionDTO> items = new ArrayList<>();
}
