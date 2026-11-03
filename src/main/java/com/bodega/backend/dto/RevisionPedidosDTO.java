package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RevisionPedidosDTO {
    private boolean hayCambio;
    private Long revision;
    private Long conteoPendientes;
    private long timestamp;
}
