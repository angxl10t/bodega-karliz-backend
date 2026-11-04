package com.bodega.backend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

@Service
public class EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailService.class);

    @Value("${resend.api.key:${RESEND_API_KEY:#{null}}}")
    private String resendApiKey;

    @Value("${brevo.api.key:${BREVO_API_KEY:#{null}}}")
    private String brevoApiKey;

    @Value("${brevo.sender.email:${BREVO_SENDER_EMAIL:cajayapos@gmail.com}}")
    private String brevoSenderEmail;

    @Value("${email.from:${EMAIL_FROM:CajaYa POS <onboarding@resend.dev>}}")
    private String emailFrom;

    private final HttpClient httpClient;

    public EmailService() {
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    /**
     * Envía el código de recuperación de contraseña de 6 dígitos al correo del bodeguero.
     * Si no hay API key configurada (ambiente de desarrollo/test), simula el envío registrándolo en consola.
     */
    public boolean enviarCodigoRecuperacion(String emailDestino, String username, String codigoOtp) {
        if (emailDestino == null || emailDestino.isBlank()) {
            log.warn("Intento de envío de código de recuperación a un email nulo o vacío.");
            return false;
        }

        String asunto = "Tu código de recuperación en CajaYa: " + codigoOtp;
        String htmlBody = construirPlantillaHtmlRecuperacion(username, codigoOtp);

        // 1. Si existe clave de Resend API, enviar vía HTTPS REST
        if (resendApiKey != null && !resendApiKey.isBlank()) {
            boolean enviado = enviarViaResend(emailDestino, asunto, htmlBody, username, codigoOtp);
            if (enviado) {
                return true;
            }
        }

        // 2. Si existe clave de Brevo API, enviar vía HTTPS REST
        if (brevoApiKey != null && !brevoApiKey.isBlank()) {
            return enviarViaBrevo(emailDestino, asunto, htmlBody);
        }

        // 3. Modo Simulación / Desarrollo (sin costos ni bloqueos de red)
        log.info("================================================================================");
        log.info(" [CAJAYA - SERVICIO DE EMAIL (MODO SIMULACIÓN / DEV)]");
        log.info(" Destinatario: {}", emailDestino);
        log.info(" Usuario:      {}", username);
        log.info(" Asunto:       {}", asunto);
        log.info(" CÓDIGO OTP:   >>> {} <<< (Válido por 15 minutos)", codigoOtp);
        log.info("================================================================================");
        return true;
    }

    private boolean enviarViaResend(String emailDestino, String asunto, String htmlContent, String username, String codigoOtp) {
        try {
            String payloadJson = "{"
                    + "\"from\":\"" + escaparJson(emailFrom) + "\","
                    + "\"to\":[\"" + escaparJson(emailDestino) + "\"],"
                    + "\"subject\":\"" + escaparJson(asunto) + "\","
                    + "\"html\":\"" + escaparJson(htmlContent) + "\""
                    + "}";

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create("https://api.resend.com/emails"))
                    .timeout(Duration.ofSeconds(15))
                    .header("Authorization", "Bearer " + resendApiKey.trim())
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(payloadJson))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                log.info("Correo de recuperación enviado con éxito vía Resend a: {}", enmascararEmail(emailDestino));
                return true;
            } else {
                log.error("Error al enviar correo vía Resend. HTTP Status: {} - Body: {}", response.statusCode(), response.body());
                log.warn("[AVISO RESEND] Si aún no has verificado un dominio propio en resend.com/domains, Resend solo enviará al correo asociado a tu cuenta de Resend o a delivered@resend.dev. Código OTP para {}: >>> {} <<<", username, codigoOtp);
                return false;
            }
        } catch (Exception e) {
            log.error("Excepción al conectar con la API de Resend: {}", e.getMessage());
            return false;
        }
    }

    private boolean enviarViaBrevo(String emailDestino, String asunto, String htmlContent) {
        try {
            String remitenteBrevo = (brevoSenderEmail != null && !brevoSenderEmail.isBlank())
                    ? brevoSenderEmail.trim()
                    : "cajayapos@gmail.com";

            String payloadJson = "{"
                    + "\"sender\":{\"name\":\"CajaYa POS\",\"email\":\"" + escaparJson(remitenteBrevo) + "\"},"
                    + "\"to\":[{\"email\":\"" + escaparJson(emailDestino) + "\"}],"
                    + "\"subject\":\"" + escaparJson(asunto) + "\","
                    + "\"htmlContent\":\"" + escaparJson(htmlContent) + "\""
                    + "}";

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create("https://api.brevo.com/v3/smtp/email"))
                    .timeout(Duration.ofSeconds(15))
                    .header("api-key", brevoApiKey.trim())
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(payloadJson))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                log.info("Correo de recuperación enviado con éxito vía Brevo a: {}", enmascararEmail(emailDestino));
                return true;
            } else {
                log.error("Error al enviar correo vía Brevo. HTTP Status: {} - Body: {}", response.statusCode(), response.body());
                return false;
            }
        } catch (Exception e) {
            log.error("Excepción al conectar con la API de Brevo: {}", e.getMessage());
            return false;
        }
    }

    public static String enmascararEmail(String email) {
        if (email == null || email.isBlank() || !email.contains("@")) {
            return "***@***";
        }
        int atIndex = email.indexOf('@');
        String name = email.substring(0, atIndex);
        String domain = email.substring(atIndex);

        if (name.length() <= 2) {
            return name.charAt(0) + "***" + domain;
        }
        return name.charAt(0) + "***" + name.charAt(name.length() - 1) + domain;
    }

    private String escaparJson(String raw) {
        if (raw == null) return "";
        return raw.replace("\\", "\\\\")
                  .replace("\"", "\\\"")
                  .replace("\b", "\\b")
                  .replace("\f", "\\f")
                  .replace("\n", "\\n")
                  .replace("\r", "\\r")
                  .replace("\t", "\\t");
    }

    private String construirPlantillaHtmlRecuperacion(String username, String codigoOtp) {
        return "<!DOCTYPE html>"
                + "<html>"
                + "<head><meta charset='UTF-8'></head>"
                + "<body style='font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif; background-color:#F8FAFC; margin:0; padding:24px; color:#1E293B;'>"
                + "  <div style='max-width:540px; margin:0 auto; background:#FFFFFF; border-radius:18px; border:1px solid #E2E8F0; padding:32px; box-shadow:0 4px 16px rgba(0,0,0,0.06);'>"
                + "    <div style='text-align:center; margin-bottom:24px;'>"
                + "      <div style='display:inline-block; background:#1E40AF; color:#FFFFFF; padding:8px 18px; border-radius:12px; font-weight:800; font-size:20px; letter-spacing:0.5px;'>"
                + "        CajaYa POS"
                + "      </div>"
                + "      <h2 style='margin:16px 0 6px 0; color:#0F172A; font-size:22px; font-weight:800;'>Restablecimiento de Contraseña</h2>"
                + "      <p style='margin:0; color:#64748B; font-size:14px;'>Hola @" + username + ", recibimos una solicitud para acceder a tu cuenta.</p>"
                + "    </div>"
                + "    <div style='background:#F0FDF4; border:1.5px dashed #16A34A; border-radius:16px; padding:20px; text-align:center; margin:24px 0;'>"
                + "      <span style='display:block; font-size:12px; font-weight:700; color:#166534; text-transform:uppercase; letter-spacing:1px; margin-bottom:6px;'>Tu Código de Verificación</span>"
                + "      <span style='font-family:monospace,Consolas; font-size:36px; font-weight:900; color:#15803D; letter-spacing:8px;'>" + codigoOtp + "</span>"
                + "      <span style='display:block; font-size:12px; color:#166534; margin-top:8px;'>⏳ Válido únicamente durante los próximos <b>15 minutos</b></span>"
                + "    </div>"
                + "    <p style='font-size:13.5px; line-height:1.6; color:#475569; margin:16px 0;'>"
                + "      Ingresa este código en tu aplicación CajaYa POS o en la web para ingresar tu nueva contraseña segura."
                + "    </p>"
                + "    <div style='background:#FEF2F2; border-left:4px solid #EF4444; border-radius:8px; padding:12px; margin-top:20px; font-size:12px; color:#991B1B;'>"
                + "      <b>¿No solicitaste este cambio?</b> Si tú no realizaste esta solicitud, puedes ignorar este mensaje de forma segura. Tu contraseña actual permanecerá intacta."
                + "    </div>"
                + "    <div style='margin-top:32px; padding-top:16px; border-top:1px solid #E2E8F0; text-align:center; font-size:11.5px; color:#94A3B8;'>"
                + "      CajaYa Cloud POS • El software oficial para bodegas y minimarkets del Perú"
                + "    </div>"
                + "  </div>"
                + "</body>"
                + "</html>";
    }
}
