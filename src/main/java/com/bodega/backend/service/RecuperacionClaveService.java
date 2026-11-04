package com.bodega.backend.service;

import com.bodega.backend.entity.RecuperacionClave;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.RecuperacionClaveRepository;
import com.bodega.backend.repository.UsuarioRepository;
import com.bodega.backend.security.LoginRateLimiterService;
import com.bodega.backend.security.UserSecurityCacheService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ThreadLocalRandom;

@Service
public class RecuperacionClaveService {

    private static final Logger log = LoggerFactory.getLogger(RecuperacionClaveService.class);

    private final UsuarioRepository usuarioRepository;
    private final RecuperacionClaveRepository recuperacionClaveRepository;
    private final EmailService emailService;
    private final PasswordEncoder passwordEncoder;
    private final LoginRateLimiterService loginRateLimiterService;
    private final UserSecurityCacheService userSecurityCacheService;

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

    @Transactional
    public Map<String, String> solicitarCodigo(String identificador, String clientIp) {
        String cleanId = (identificador != null) ? identificador.trim().toLowerCase() : "";
        if (cleanId.isBlank()) {
            throw new RuntimeException("Debes ingresar tu nombre de usuario o correo electrónico.");
        }

        if (loginRateLimiterService.isBlocked(clientIp, cleanId)) {
            long remaining = loginRateLimiterService.getRemainingBlockMinutes(clientIp, cleanId);
            throw new RuntimeException("Demasiados intentos. Operación bloqueada temporalmente por " + remaining + " minuto(s).");
        }

        Optional<Usuario> usuarioOpt = usuarioRepository.findByUsernameOrEmailIgnoreCase(cleanId);

        Map<String, String> response = new HashMap<>();
        String mensajeGenerico = "Si la cuenta existe y tiene un correo asociado, hemos enviado un código de verificación de 6 dígitos.";

        if (usuarioOpt.isEmpty()) {
            loginRateLimiterService.registerFailedAttempt(clientIp, cleanId);
            response.put("mensaje", mensajeGenerico);
            response.put("emailEnmascarado", "");
            return response;
        }

        Usuario usuario = usuarioOpt.get();
        if (usuario.getEmail() == null || usuario.getEmail().isBlank()) {
            log.warn("Usuario {} solicitó recuperación pero no tiene correo registrado.", usuario.getUsername());
            response.put("mensaje", "La cuenta @" + usuario.getUsername() + " no tiene un correo electrónico configurado para recuperación. Por favor contacta al administrador de tu bodega o al soporte.");
            response.put("emailEnmascarado", "");
            response.put("sinEmail", "true");
            return response;
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
        recuperacionClaveRepository.save(nuevoRegistro);

        // Enviar correo transaccional
        emailService.enviarCodigoRecuperacion(usuario.getEmail(), usuario.getUsername(), codigoStr);

        response.put("mensaje", mensajeGenerico);
        response.put("emailEnmascarado", EmailService.enmascararEmail(usuario.getEmail()));
        response.put("expiraMinutos", "15");
        return response;
    }

    @Transactional
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

        Usuario usuario = usuarioRepository.findByUsernameOrEmailIgnoreCase(cleanId)
                .orElseThrow(() -> new RuntimeException("Código de verificación incorrecto o expirado."));

        List<RecuperacionClave> activos = recuperacionClaveRepository
                .findByUsuarioAndUsadoFalseAndExpiracionAfterOrderByFechaCreacionDesc(usuario, OffsetDateTime.now());

        if (activos.isEmpty()) {
            loginRateLimiterService.registerFailedAttempt(clientIp, cleanId);
            throw new RuntimeException("El código ha expirado o ya fue utilizado. Por favor solicita uno nuevo.");
        }

        RecuperacionClave token = activos.get(0);
        String hashIngresado = calcularSha256(cleanCode);

        if (!token.getCodigoHash().equals(hashIngresado)) {
            token.setIntentosFallidos(token.getIntentosFallidos() + 1);
            if (token.getIntentosFallidos() >= 5) {
                token.setUsado(true);
            }
            recuperacionClaveRepository.save(token);
            loginRateLimiterService.registerFailedAttempt(clientIp, cleanId);

            int restantes = Math.max(0, 5 - token.getIntentosFallidos());
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

    @Transactional
    public Map<String, String> restablecerPassword(String identificador, String codigo, String nuevaPassword, String clientIp) {
        String cleanId = (identificador != null) ? identificador.trim().toLowerCase() : "";
        String cleanCode = (codigo != null) ? codigo.trim() : "";

        if (nuevaPassword == null || nuevaPassword.trim().length() < 4 || nuevaPassword.trim().length() > 72) {
            throw new RuntimeException("La nueva contraseña debe tener entre 4 y 72 caracteres.");
        }

        // Valida el código
        Usuario usuario = usuarioRepository.findByUsernameOrEmailIgnoreCase(cleanId)
                .orElseThrow(() -> new RuntimeException("Código de verificación incorrecto o expirado."));

        List<RecuperacionClave> activos = recuperacionClaveRepository
                .findByUsuarioAndUsadoFalseAndExpiracionAfterOrderByFechaCreacionDesc(usuario, OffsetDateTime.now());

        if (activos.isEmpty()) {
            throw new RuntimeException("El código ha expirado o ya no es válido. Solicita uno nuevo.");
        }

        RecuperacionClave token = activos.get(0);
        String hashIngresado = calcularSha256(cleanCode);

        if (!token.getCodigoHash().equals(hashIngresado)) {
            token.setIntentosFallidos(token.getIntentosFallidos() + 1);
            if (token.getIntentosFallidos() >= 5) {
                token.setUsado(true);
            }
            recuperacionClaveRepository.save(token);
            throw new RuntimeException("Código de verificación incorrecto.");
        }

        // Cambiar contraseña
        usuario.setPassword(passwordEncoder.encode(nuevaPassword.trim()));
        usuario.setFechaCambioClave(OffsetDateTime.now());
        usuarioRepository.save(usuario);

        // Marcar token como utilizado
        token.setUsado(true);
        recuperacionClaveRepository.save(token);

        // Limpiar intentos de rate limit y desalojar caché de seguridad
        loginRateLimiterService.resetAttempts(clientIp, usuario.getUsername());
        userSecurityCacheService.evict(usuario.getUsername());

        log.info("Contraseña restablecida con éxito para el usuario: {}", usuario.getUsername());

        Map<String, String> res = new HashMap<>();
        res.put("mensaje", "¡Tu contraseña ha sido restablecida con éxito! Ya puedes iniciar sesión en CajaYa.");
        res.put("username", usuario.getUsername());
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
