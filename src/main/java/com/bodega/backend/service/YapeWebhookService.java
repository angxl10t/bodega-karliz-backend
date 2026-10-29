package com.bodega.backend.service;

import com.bodega.backend.dto.WebhookYapeDTO;
import com.bodega.backend.entity.YapeTransaccionRecibida;
import com.bodega.backend.repository.YapeTransaccionRecibidaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class YapeWebhookService {

    private static final Logger log = LoggerFactory.getLogger(YapeWebhookService.class);

    // Patrones regex para parsing resiliente de notificaciones oficiales de Yape y Plin
    private static final Pattern PATTERN_MONTO = Pattern.compile("(?:S/\\.?|S/|PEN|monto:?\\s*S/?)\\s*([0-9]+(?:\\.[0-9]{1,2})?)", Pattern.CASE_INSENSITIVE);
    private static final Pattern PATTERN_COD_OP = Pattern.compile("(?:operaci[oó]n|op|nro|c[oó]digo|cod|ref)[\\s.:#]*([0-9]{4,15})", Pattern.CASE_INSENSITIVE);
    private static final Pattern PATTERN_REMITENTE = Pattern.compile("de\\s+([A-Za-zÁÉÍÓÚñáéíóú\\s]{3,35})(?:\\.|\\s+Nro|\\s+Op|\\s+operaci|\\s+por|\\s+con|$)", Pattern.CASE_INSENSITIVE);

    private final YapeTransaccionRecibidaRepository yapeTransaccionRecibidaRepository;

    @Value("${cajaya.yape.webhook-secret:CajayaYapeSecretKey2026Secure}")
    private String configuredSecret;

    public YapeWebhookService(YapeTransaccionRecibidaRepository yapeTransaccionRecibidaRepository) {
        this.yapeTransaccionRecibidaRepository = yapeTransaccionRecibidaRepository;
    }

    @Transactional
    public YapeTransaccionRecibida procesarNotificacionYape(String secretHeader, WebhookYapeDTO dto) {
        // Validación de Autenticidad del Token Secreto (Blindaje contra llamadas no autorizadas)
        if (secretHeader == null || !secretHeader.trim().equals(configuredSecret.trim())) {
            log.warn("[YapeWebhook] Intento de acceso no autorizado con secret incorrecto o ausente.");
            throw new org.springframework.security.access.AccessDeniedException("Acceso no autorizado: Token secreto X-Yape-Secret inválido o ausente.");
        }

        String raw = dto.getTextoNotificacion() != null ? dto.getTextoNotificacion() : "";
        String codOp = dto.getCodigoOperacion();
        BigDecimal monto = dto.getMonto();
        String billetera = dto.getBilletera() != null ? dto.getBilletera().toUpperCase().trim() : "";
        String remitente = dto.getNombreRemitente();

        // Si faltan datos estructurados pero vino el texto de la notificación push, parsear con regex
        if ((codOp == null || codOp.isBlank()) && !raw.isBlank()) {
            Matcher mOp = PATTERN_COD_OP.matcher(raw);
            if (mOp.find()) {
                codOp = mOp.group(1).trim();
            }
        }

        if (monto == null && !raw.isBlank()) {
            Matcher mMonto = PATTERN_MONTO.matcher(raw);
            if (mMonto.find()) {
                try {
                    monto = new BigDecimal(mMonto.group(1).trim());
                } catch (Exception ignored) {}
            }
        }

        if (billetera.isBlank()) {
            billetera = raw.toLowerCase().contains("plin") ? "PLIN" : "YAPE";
        }

        if ((remitente == null || remitente.isBlank()) && !raw.isBlank()) {
            Matcher mRem = PATTERN_REMITENTE.matcher(raw);
            if (mRem.find()) {
                remitente = mRem.group(1).trim();
            }
        }

        if (codOp == null || codOp.isBlank()) {
            throw new IllegalArgumentException("No se pudo identificar el código de operación en la notificación recibida.");
        }

        if (monto == null || monto.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("No se pudo identificar un monto válido en la notificación recibida.");
        }

        // Idempotencia: Si ya se recibió antes esta misma notificación, retornar la existente sin duplicar
        var existenteOpt = yapeTransaccionRecibidaRepository.findFirstByCodigoOperacion(codOp);
        if (existenteOpt.isPresent()) {
            log.info("[YapeWebhook] Notificación de operación {} ya registrada previamente. Idempotente.", codOp);
            return existenteOpt.get();
        }

        YapeTransaccionRecibida tx = new YapeTransaccionRecibida();
        tx.setCodigoOperacion(codOp);
        tx.setMonto(monto);
        tx.setBilletera(billetera);
        tx.setNombreRemitente(remitente);
        tx.setTextoNotificacion(raw);
        tx.setUsado(false);

        YapeTransaccionRecibida guardada = yapeTransaccionRecibidaRepository.save(tx);
        log.info("[YapeWebhook] Nueva transacción {} registrada exitosamente. Op: {}, Monto: S/ {}, Remitente: {}", 
                billetera, codOp, monto, remitente);
        return guardada;
    }

    @Transactional(readOnly = true)
    public List<YapeTransaccionRecibida> listarTodas() {
        return yapeTransaccionRecibidaRepository.findAllByOrderByFechaRecepcionDesc();
    }
}
