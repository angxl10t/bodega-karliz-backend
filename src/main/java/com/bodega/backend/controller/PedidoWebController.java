package com.bodega.backend.controller;

import com.bodega.backend.dto.PedidoWebDTO;
import com.bodega.backend.dto.RevisionPedidosDTO;
import com.bodega.backend.service.PedidoWebService;
import com.bodega.backend.service.TenantService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/pedidos-web")
public class PedidoWebController {

    private final PedidoWebService pedidoWebService;
    private final TenantService tenantService;

    public PedidoWebController(PedidoWebService pedidoWebService,
                               TenantService tenantService) {
        this.pedidoWebService = pedidoWebService;
        this.tenantService = tenantService;
    }

    /**
     * Endpoint de sondeo ultraligero en memoria (Zero-DB Hit en idle):
     * Permite a las cajas POS saber en menos de 1ms si ingresó un nuevo pedido web
     * sin consumir conexiones del pool de PostgreSQL ni saturar la CPU.
     */
    @GetMapping("/revision")
    public ResponseEntity<RevisionPedidosDTO> consultarRevision(@RequestParam(required = false) Long ultimaRevision) {
        Long idBodega = tenantService.getCurrentBodegaId();
        RevisionPedidosDTO dto = pedidoWebService.verificarRevision(idBodega, ultimaRevision);
        return ResponseEntity.ok(dto);
    }

    /**
     * Lista los pedidos web recibidos (por defecto los PENDIENTES o todos).
     */
    @GetMapping
    public ResponseEntity<List<PedidoWebDTO>> listarPedidos(
            @RequestParam(required = false, defaultValue = "TODOS") String estado,
            @RequestParam(required = false, defaultValue = "50") int limite) {
        Long idBodega = tenantService.getCurrentBodegaId();
        List<PedidoWebDTO> lista = pedidoWebService.listarPedidos(idBodega, estado, limite);
        return ResponseEntity.ok(lista);
    }

    /**
     * Búsqueda rápida por código corto (#W-XXXX), nombre o teléfono del cliente.
     */
    @GetMapping("/buscar")
    public ResponseEntity<List<PedidoWebDTO>> buscarPedidos(
            @RequestParam(required = false, defaultValue = "") String query,
            @RequestParam(required = false, defaultValue = "20") int limite) {
        Long idBodega = tenantService.getCurrentBodegaId();
        List<PedidoWebDTO> resultados = pedidoWebService.buscarPedidos(idBodega, query, limite);
        return ResponseEntity.ok(resultados);
    }

    /**
     * Actualiza el estado de un pedido (ej. de PENDIENTE a CARGADO_EN_POS o COMPLETADO).
     */
    @PutMapping("/{id}/estado")
    public ResponseEntity<PedidoWebDTO> actualizarEstado(
            @PathVariable Long id,
            @RequestParam(required = false, defaultValue = "CARGADO_EN_POS") String nuevoEstado) {
        Long idBodega = tenantService.getCurrentBodegaId();
        PedidoWebDTO actualizado = pedidoWebService.actualizarEstado(idBodega, id, nuevoEstado);
        return ResponseEntity.ok(actualizado);
    }

    /**
     * Elimina un pedido web descartado o erróneo.
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> eliminarPedido(@PathVariable Long id) {
        Long idBodega = tenantService.getCurrentBodegaId();
        pedidoWebService.eliminarPedido(idBodega, id);
        return ResponseEntity.ok(Map.of("mensaje", "Pedido web eliminado correctamente", "id", id));
    }
}
