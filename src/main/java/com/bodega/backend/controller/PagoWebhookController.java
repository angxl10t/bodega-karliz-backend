package com.bodega.backend.controller;

import com.bodega.backend.dto.WebhookYapeDTO;
import com.bodega.backend.entity.YapeTransaccionRecibida;
import com.bodega.backend.service.YapeWebhookService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/pagos")
public class PagoWebhookController {

    private final YapeWebhookService yapeWebhookService;

    public PagoWebhookController(YapeWebhookService yapeWebhookService) {
        this.yapeWebhookService = yapeWebhookService;
    }

    /**
     * Endpoint receptor de notificaciones push de Yape / Plin.
     * Llamado automáticamente por la app Android Listener en el teléfono de Luis T.
     * Protegido por el encabezado X-Yape-Secret.
     */
    @PostMapping("/webhook-yape-listener")
    public ResponseEntity<Map<String, Object>> recibirNotificacionYape(
            @RequestHeader(value = "X-Yape-Secret", required = false) String secretHeader,
            @RequestBody WebhookYapeDTO dto) {

        YapeTransaccionRecibida tx = yapeWebhookService.procesarNotificacionYape(secretHeader, dto);

        return ResponseEntity.ok(Map.of(
                "status", "PROCESSED",
                "codigoOperacion", tx.getCodigoOperacion(),
                "monto", tx.getMonto(),
                "billetera", tx.getBilletera(),
                "mensaje", "Notificación Yape/Plin registrada exitosamente en CajaYa Cloud POS"
        ));
    }

    /**
     * Consulta administrativa de transacciones recibidas vía webhook.
     * Solo accesible por SUPERADMIN para auditoría y conciliación.
     */
    @GetMapping("/yape-transacciones")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<List<YapeTransaccionRecibida>> listarTransaccionesYape() {
        return ResponseEntity.ok(yapeWebhookService.listarTodas());
    }
}
