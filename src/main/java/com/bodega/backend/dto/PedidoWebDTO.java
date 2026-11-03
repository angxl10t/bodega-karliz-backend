package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PedidoWebDTO {
    private Long idPedidoWeb;
    private String idPedido;
    private String codigoPedido;
    private OffsetDateTime fecha;
    private String nombreCliente;
    private String telefonoCliente;
    private String notas;
    private BigDecimal total;
    private BigDecimal ahorroPromociones;
    private Boolean incluyeRetornables;
    private String estado;
    @Builder.Default
    private List<PedidoWebDetalleDTO> items = new ArrayList<>();
}
