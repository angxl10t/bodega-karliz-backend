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
     * Endpoint POST receptor de notificaciones push de Yape / Plin.
     * Admite secreto vía header X-Yape-Secret o query param ?secret=...
     */
    @PostMapping("/webhook-yape-listener")
    public ResponseEntity<Map<String, Object>> recibirNotificacionYapePost(
            @RequestHeader(value = "X-Yape-Secret", required = false) String secretHeader,
            @RequestParam(value = "secret", required = false) String secretParam,
            @RequestBody(required = false) WebhookYapeDTO dto) {

        String secret = secretHeader != null ? secretHeader : secretParam;
        if (dto == null) {
            dto = new WebhookYapeDTO();
        }
        YapeTransaccionRecibida tx = yapeWebhookService.procesarNotificacionYape(secret, dto);

        return ResponseEntity.ok(Map.of(
                "status", "PROCESSED",
                "codigoOperacion", tx.getCodigoOperacion(),
                "monto", tx.getMonto(),
                "billetera", tx.getBilletera(),
                "mensaje", "Notificación Yape/Plin registrada exitosamente en CajaYa Cloud POS"
        ));
    }

    /**
     * Endpoint GET receptor de notificaciones (ideal para automatizaciones móviles rápidas,
     * "Abrir sitio web / HTTP GET" en MacroDroid, Tasker o navegadores).
     * Ejemplo: /api/pagos/webhook-yape-listener?secret=CajayaYapeSecretKey2026Secure&texto=[not_body]
     */
    @GetMapping("/webhook-yape-listener")
    public ResponseEntity<Map<String, Object>> recibirNotificacionYapeGet(
            @RequestHeader(value = "X-Yape-Secret", required = false) String secretHeader,
            @RequestParam(value = "secret", required = false) String secretParam,
            @RequestParam(value = "texto", required = false) String texto,
            @RequestParam(value = "notificacion", required = false) String notificacion,
            @RequestParam(value = "codigoOperacion", required = false) String codigoOperacion,
            @RequestParam(value = "monto", required = false) java.math.BigDecimal monto,
            @RequestParam(value = "billetera", required = false) String billetera,
            @RequestParam(value = "remitente", required = false) String remitente) {

        String secret = secretHeader != null ? secretHeader : secretParam;
        WebhookYapeDTO dto = new WebhookYapeDTO();
        dto.setTextoNotificacion(texto != null ? texto : notificacion);
        dto.setCodigoOperacion(codigoOperacion);
        dto.setMonto(monto);
        dto.setBilletera(billetera);
        dto.setNombreRemitente(remitente);

        YapeTransaccionRecibida tx = yapeWebhookService.procesarNotificacionYape(secret, dto);

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
