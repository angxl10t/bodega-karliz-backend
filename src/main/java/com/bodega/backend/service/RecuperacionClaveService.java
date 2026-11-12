package com.bodega.backend.service;

import com.bodega.backend.entity.RecuperacionClave;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.RecuperacionClaveRepository;
import com.bodega.backend.repository.UsuarioRepository;
import com.bodega.backend.security.LoginRateLimiterService;
import com.bodega.backend.security.UserSecurityCacheService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ThreadLocalRandom;
import java.util.function.Supplier;

@Service
public class RecuperacionClaveService {

    private static final Logger log = LoggerFactory.getLogger(RecuperacionClaveService.class);

    private final UsuarioRepository usuarioRepository;
    private final RecuperacionClaveRepository recuperacionClaveRepository;
    private final EmailService emailService;
    private final PasswordEncoder passwordEncoder;
    private final LoginRateLimiterService loginRateLimiterService;
    private final UserSecurityCacheService userSecurityCacheService;
    private TransactionTemplate transactionTemplate;

    public RecuperacionClaveService(UsuarioRepository usuarioRepository,
                                    RecuperacionClaveRepository recuperacionClaveRepository,
                                    EmailService emailService,
                                    PasswordEncoder passwordEncoder,
                                    LoginRateLimiterService loginRateLimiterService,
                                    UserSecurityCacheService userSecurityCacheService) {
        this.usuarioRepository = usuarioRepository;
        this.recuperacionClaveRepository = recuperacionClaveRepository;
        this.emailService = emailService;
        this.passwordEncoder = passwordEncoder;
        this.loginRateLimiterService = loginRateLimiterService;
        this.userSecurityCacheService = userSecurityCacheService;
    }

    @Autowired(required = false)
    public void setTransactionManager(PlatformTransactionManager transactionManager) {
        if (transactionManager != null) {
            this.transactionTemplate = new TransactionTemplate(transactionManager);
        }
    }

    private <T> T executeInTransaction(Supplier<T> action) {
        if (transactionTemplate != null) {
            return transactionTemplate.execute(status -> action.get());
        }
        return action.get();
    }

    public Map<String, String> solicitarCodigo(String identificador, String clientIp) {
        String cleanId = (identificador != null) ? identificador.trim().toLowerCase() : "";
        if (cleanId.isBlank()) {
            throw new RuntimeException("Debes ingresar tu nombre de usuario o correo electrónico.");
        }

        if (loginRateLimiterService.isBlocked(clientIp, cleanId)) {
            long remaining = loginRateLimiterService.getRemainingBlockMinutes(clientIp, cleanId);
            throw new RuntimeException("Demasiados intentos. Operación bloqueada temporalmente por " + remaining + " minuto(s).");
        }

        Map<String, String> response = new HashMap<>();
        String mensajeGenerico = "Si la cuenta existe y tiene un correo asociado, hemos enviado un código de verificación de 6 dígitos.";

        String[] envioPendiente = executeInTransaction(() -> {
            Optional<Usuario> usuarioOpt = usuarioRepository.findByUsernameOrEmailIgnoreCase(cleanId);
            if (usuarioOpt.isEmpty()) {
                return new String[]{"NOT_FOUND"};
            }

            Usuario usuario = usuarioOpt.get();
            if (usuario.getEmail() == null || usuario.getEmail().isBlank()) {
                log.warn("Usuario {} solicitó recuperación pero no tiene correo registrado.", usuario.getUsername());
                response.put("mensaje", "La cuenta @" + usuario.getUsername() + " no tiene un correo electrónico configurado para recuperación. Por favor contacta al administrador de tu bodega o al soporte.");
                response.put("emailEnmascarado", "");
                response.put("sinEmail", "true");
                return new String[]{"NO_EMAIL"};
            }

            // Tasa máxima: hasta 3 códigos por usuario cada 15 minutos
            long recientes = recuperacionClaveRepository.countByUsuarioAndFechaCreacionAfter(
                    usuario, OffsetDateTime.now().minusMinutes(15));
            if (recientes >= 3) {
                throw new RuntimeException("Has solicitado varios códigos recientemente. Por favor espera 15 minutos antes de solicitar uno nuevo.");
            }

            // Invalidar códigos anteriores aún no usados
            List<RecuperacionClave> previos = recuperacionClaveRepository.findByUsuarioAndUsadoFalse(usuario);
            for (RecuperacionClave r : previos) {
                r.setUsado(true);
            }
            recuperacionClaveRepository.saveAll(previos);

            // Generar código numérico criptográfico de 6 dígitos (100000 - 999999)
            int randomCode = ThreadLocalRandom.current().nextInt(100000, 1000000);
            String codigoStr = String.valueOf(randomCode);
            String hash = calcularSha256(codigoStr);

            RecuperacionClave nuevoRegistro = new RecuperacionClave();
            nuevoRegistro.setUsuario(usuario);
            nuevoRegistro.setCodigoHash(hash);
            nuevoRegistro.setEmailDestino(usuario.getEmail());
            nuevoRegistro.setExpiracion(OffsetDateTime.now().plusMinutes(15));
            nuevoRegistro.setUsado(false);
            nuevoRegistro.setIntentosFallidos(0);
            RecuperacionClave guardado = recuperacionClaveRepository.save(nuevoRegistro);

            return new String[]{
                    "SEND",
                    usuario.getEmail(),
                    usuario.getUsername(),
                    codigoStr,
                    guardado != null && guardado.getId() != null ? String.valueOf(guardado.getId()) : ""
            };
        });

        if ("NOT_FOUND".equals(envioPendiente[0])) {
            loginRateLimiterService.registerFailedAttempt(clientIp, cleanId);
            response.put("mensaje", mensajeGenerico);
            response.put("emailEnmascarado", "");
            return response;
        }
        if ("NO_EMAIL".equals(envioPendiente[0])) {
            return response;
        }

        // Enviar correo transaccional fuera de la transacción DB para no retener conexiones HikariCP
        String emailDestino = envioPendiente[1];
        boolean enviado = emailService.enviarCodigoRecuperacion(emailDestino, envioPendiente[2], envioPendiente[3]);
        if (!enviado) {
            String tokenIdStr = envioPendiente.length > 4 ? envioPendiente[4] : "";
            if (tokenIdStr != null && !tokenIdStr.isBlank()) {
                Long tokenId = Long.valueOf(tokenIdStr);
                executeInTransaction(() -> {
                    recuperacionClaveRepository.deleteById(tokenId);
                    return null;
                });
            }
            throw new RuntimeException("No se pudo enviar el código de recuperación por correo electrónico en este momento. Intenta nuevamente más tarde.");
        }

        response.put("mensaje", mensajeGenerico);
        response.put("emailEnmascarado", EmailService.enmascararEmail(emailDestino));
        response.put("expiraMinutos", "15");
        return response;
    }

    public Map<String, String> verificarCodigo(String identificador, String codigo, String clientIp) {
        String cleanId = (identificador != null) ? identificador.trim().toLowerCase() : "";
        String cleanCode = (codigo != null) ? codigo.trim() : "";

        if (cleanId.isBlank() || cleanCode.length() != 6) {
            throw new RuntimeException("El identificador y el código de 6 dígitos son obligatorios.");
        }

        if (loginRateLimiterService.isBlocked(clientIp, cleanId)) {
            long remaining = loginRateLimiterService.getRemainingBlockMinutes(clientIp, cleanId);
            throw new RuntimeException("Demasiados intentos. Operación bloqueada por " + remaining + " minuto(s).");
        }

        String hashIngresado = calcularSha256(cleanCode);

        int[] resultado = executeInTransaction(() -> {
            Usuario usuario = usuarioRepository.findByUsernameOrEmailIgnoreCase(cleanId)
                    .orElseThrow(() -> new RuntimeException("Código de verificación incorrecto o expirado."));

            List<RecuperacionClave> activos = recuperacionClaveRepository
                    .findByUsuarioAndUsadoFalseAndExpiracionAfterOrderByFechaCreacionDesc(usuario, OffsetDateTime.now());

            if (activos.isEmpty()) {
                return new int[]{-1, 0};
            }

            RecuperacionClave token = activos.get(0);
            if (!token.getCodigoHash().equals(hashIngresado)) {
                token.setIntentosFallidos(token.getIntentosFallidos() + 1);
                if (token.getIntentosFallidos() >= 5) {
                    token.setUsado(true);
                }
                recuperacionClaveRepository.save(token);
                int restantes = Math.max(0, 5 - token.getIntentosFallidos());
                return new int[]{0, restantes};
            }

            return new int[]{1, 0};
        });

        if (resultado[0] == -1) {
            loginRateLimiterService.registerFailedAttempt(clientIp, cleanId);
            throw new RuntimeException("El código ha expirado o ya fue utilizado. Por favor solicita uno nuevo.");
        }

        if (resultado[0] == 0) {
            loginRateLimiterService.registerFailedAttempt(clientIp, cleanId);
            int restantes = resultado[1];
            if (restantes == 0) {
                throw new RuntimeException("Has agotado los 5 intentos para este código. Por favor solicita uno nuevo.");
            }
            throw new RuntimeException("Código incorrecto. Te quedan " + restantes + " intento(s).");
        }

        Map<String, String> res = new HashMap<>();
        res.put("valido", "true");
        res.put("mensaje", "Código verificado correctamente.");
        return res;
    }

    public Map<String, String> restablecerPassword(String identificador, String codigo, String nuevaPassword, String clientIp) {
        String cleanId = (identificador != null) ? identificador.trim().toLowerCase() : "";
        String cleanCode = (codigo != null) ? codigo.trim() : "";

        if (nuevaPassword == null || nuevaPassword.trim().length() < 4 || nuevaPassword.trim().length() > 72) {
            throw new RuntimeException("La nueva contraseña debe tener entre 4 y 72 caracteres.");
        }

        String encodedPassword = passwordEncoder.encode(nuevaPassword.trim());
        String hashIngresado = calcularSha256(cleanCode);

        String username = executeInTransaction(() -> {
            Usuario usuario = usuarioRepository.findByUsernameOrEmailIgnoreCase(cleanId)
                    .orElseThrow(() -> new RuntimeException("Código de verificación incorrecto o expirado."));

            List<RecuperacionClave> activos = recuperacionClaveRepository
                    .findByUsuarioAndUsadoFalseAndExpiracionAfterOrderByFechaCreacionDesc(usuario, OffsetDateTime.now());

            if (activos.isEmpty()) {
                throw new RuntimeException("El código ha expirado o ya no es válido. Solicita uno nuevo.");
            }

            RecuperacionClave token = activos.get(0);
            if (!token.getCodigoHash().equals(hashIngresado)) {
                token.setIntentosFallidos(token.getIntentosFallidos() + 1);
                if (token.getIntentosFallidos() >= 5) {
                    token.setUsado(true);
                }
                recuperacionClaveRepository.save(token);
                return null;
            }

            usuario.setPassword(encodedPassword);
            usuario.setFechaCambioClave(OffsetDateTime.now());
            usuarioRepository.save(usuario);

            token.setUsado(true);
            recuperacionClaveRepository.save(token);

            return usuario.getUsername();
        });

        if (username == null) {
            throw new RuntimeException("Código de verificación incorrecto.");
        }

        // Limpiar intentos de rate limit y desalojar caché de seguridad
        loginRateLimiterService.resetAttempts(clientIp, username);
        userSecurityCacheService.evict(username);

        log.info("Contraseña restablecida con éxito para el usuario: {}", username);

        Map<String, String> res = new HashMap<>();
        res.put("mensaje", "¡Tu contraseña ha sido restablecida con éxito! Ya puedes iniciar sesión en CajaYa.");
        res.put("username", username);
        return res;
    }

    private String calcularSha256(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] encodedhash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder(2 * encodedhash.length);
            for (byte b : encodedhash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) {
                    hexString.append('0');
                }
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("Error criptográfico al calcular hash SHA-256", e);
        }
    }
}
