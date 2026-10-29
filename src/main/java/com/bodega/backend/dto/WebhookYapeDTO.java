package com.bodega.backend.dto;

import lombok.Data;

import java.math.BigDecimal;

/**
 * Payload recibido desde la app listener de notificaciones en el teléfono Android.
 * Admite tanto datos parseados previamente como el texto crudo de la notificación.
 */
@Data
public class WebhookYapeDTO {

    private String codigoOperacion;

    private BigDecimal monto;

    private String billetera; // YAPE, PLIN

    private String nombreRemitente;

    private String textoNotificacion; // Texto crudo de la notificación para parser resiliente
}
