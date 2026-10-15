package com.bodega.backend.controller;

import com.bodega.backend.dto.AuthDTO;
import com.bodega.backend.dto.CambiarPasswordDTO;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.UsuarioRepository;
import com.bodega.backend.security.JwtUtil;
import com.bodega.backend.security.LoginRateLimiterService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtUtil jwtUtil;
    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;
    private final LoginRateLimiterService loginRateLimiterService;

    public AuthController(AuthenticationManager authenticationManager, JwtUtil jwtUtil, 
                          UsuarioRepository usuarioRepository, PasswordEncoder passwordEncoder,
                          LoginRateLimiterService loginRateLimiterService) {
        this.authenticationManager = authenticationManager;
        this.jwtUtil = jwtUtil;
        this.usuarioRepository = usuarioRepository;
        this.passwordEncoder = passwordEncoder;
        this.loginRateLimiterService = loginRateLimiterService;
    }

    @PostMapping("/login")
    public ResponseEntity<Map<String, String>> login(@Valid @RequestBody AuthDTO authDTO, HttpServletRequest request) {
        String clientIp = extractClientIp(request);
        String username = authDTO.getUsername() != null ? authDTO.getUsername().trim() : "";

        // 1. Verificación previa de Rate Limiting (sin tocar la base de datos ni el pool Hikari)
        if (loginRateLimiterService.isBlocked(clientIp, username)) {
            long remaining = loginRateLimiterService.getRemainingBlockMinutes(clientIp, username);
            Map<String, String> err = new HashMap<>();
            err.put("error", "Demasiados intentos fallidos. Acceso bloqueado temporalmente por " + remaining + " minuto(s) por seguridad.");
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(err);
        }

        try {
            // 2. Valida usuario y contraseña en BD
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(username, authDTO.getPassword())
            );
        } catch (BadCredentialsException ex) {
            loginRateLimiterService.registerFailedAttempt(clientIp, username);
            throw ex;
        } catch (Exception ex) {
            loginRateLimiterService.registerFailedAttempt(clientIp, username);
            throw ex;
        }

        // 3. Login exitoso: limpiar contador de intentos
        loginRateLimiterService.resetAttempts(clientIp, username);

        // 4. Genera el JWT
        Usuario usuario = usuarioRepository.findByUsernameIgnoreCase(username)
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));
        String jwt = jwtUtil.generateToken(usuario.getUsername(), usuario.getRol());

        // 5. Retorna credenciales al cliente
        Map<String, String> response = new HashMap<>();
        response.put("token", jwt);
        response.put("rol", usuario.getRol());
        return ResponseEntity.ok(response);
    }

    private String extractClientIp(HttpServletRequest request) {
        String xf = request.getHeader("X-Forwarded-For");
        if (xf != null && !xf.isBlank()) {
            return xf.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }

    @PostMapping("/cambiar-password")
    public ResponseEntity<Map<String, String>> cambiarPassword(
            @Valid @RequestBody CambiarPasswordDTO dto,
            Principal principal,
            HttpServletRequest request) {
        if (principal == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String clientIp = extractClientIp(request);
        String username = principal.getName();

        // 1. Verificación previa de Rate Limiting para evitar ataques de fuerza bruta al passwordActual
        if (loginRateLimiterService.isBlocked(clientIp, username)) {
            long remaining = loginRateLimiterService.getRemainingBlockMinutes(clientIp, username);
            Map<String, String> err = new HashMap<>();
            err.put("error", "Demasiados intentos fallidos. Operación bloqueada temporalmente por " + remaining + " minuto(s) por seguridad.");
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(err);
        }

        // 2. Prevenir reutilización inmediata de la misma contraseña
        if (dto.getPasswordActual().equals(dto.getNuevaPassword())) {
            throw new RuntimeException("La nueva contraseña no puede ser idéntica a la contraseña actual.");
        }

        Usuario usuario = usuarioRepository.findByUsernameIgnoreCase(username)
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));

        // 3. Validación de contraseña actual con penalización en caso de fallo
        if (!passwordEncoder.matches(dto.getPasswordActual(), usuario.getPassword())) {
            loginRateLimiterService.registerFailedAttempt(clientIp, username);
            throw new RuntimeException("La contraseña actual no es correcta.");
        }

        // 4. Éxito: limpiar penalizaciones, actualizar hash y registrar fecha de cambio
        loginRateLimiterService.resetAttempts(clientIp, username);
        usuario.setPassword(passwordEncoder.encode(dto.getNuevaPassword()));
        usuario.setFechaCambioClave(java.time.OffsetDateTime.now());
        usuarioRepository.save(usuario);

        Map<String, String> response = new HashMap<>();
        response.put("mensaje", "Contraseña actualizada exitosamente.");
        return ResponseEntity.ok(response);
    }
}
