package com.bodega.backend.controller;

import com.bodega.backend.dto.*;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.UsuarioRepository;
import com.bodega.backend.security.JwtUtil;
import com.bodega.backend.security.LoginRateLimiterService;
import com.bodega.backend.service.RecuperacionClaveService;
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
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtUtil jwtUtil;
    private final UsuarioRepository usuarioRepository;
    private final com.bodega.backend.repository.BodegaRepository bodegaRepository;
    private final com.bodega.backend.repository.CategoriaRepository categoriaRepository;
    private final PasswordEncoder passwordEncoder;
    private final LoginRateLimiterService loginRateLimiterService;
    private final com.bodega.backend.security.UserSecurityCacheService userSecurityCacheService;
    private final com.bodega.backend.service.StarterPackService starterPackService;
    private final RecuperacionClaveService recuperacionClaveService;

    public AuthController(AuthenticationManager authenticationManager, JwtUtil jwtUtil, 
                          UsuarioRepository usuarioRepository,
                          com.bodega.backend.repository.BodegaRepository bodegaRepository,
                          com.bodega.backend.repository.CategoriaRepository categoriaRepository,
                          PasswordEncoder passwordEncoder,
                          LoginRateLimiterService loginRateLimiterService,
                          com.bodega.backend.security.UserSecurityCacheService userSecurityCacheService,
                          com.bodega.backend.service.StarterPackService starterPackService,
                          RecuperacionClaveService recuperacionClaveService) {
        this.authenticationManager = authenticationManager;
        this.jwtUtil = jwtUtil;
        this.usuarioRepository = usuarioRepository;
        this.bodegaRepository = bodegaRepository;
        this.categoriaRepository = categoriaRepository;
        this.passwordEncoder = passwordEncoder;
        this.loginRateLimiterService = loginRateLimiterService;
        this.userSecurityCacheService = userSecurityCacheService;
        this.starterPackService = starterPackService;
        this.recuperacionClaveService = recuperacionClaveService;
    }

    @PostMapping("/login")
    public ResponseEntity<Map<String, String>> login(@Valid @RequestBody AuthDTO authDTO, HttpServletRequest request) {
        String clientIp = extractClientIp(request);
        String username = authDTO.getUsername() != null ? authDTO.getUsername().trim() : "";

        // Mitigación de Fuerza Bruta: Rechazo inmediato si IP o usuario superaron 5 intentos fallidos
        if (loginRateLimiterService.isBlocked(clientIp, username)) {
            long remainingMinutes = loginRateLimiterService.getRemainingBlockMinutes(clientIp, username);
            Map<String, String> response = new HashMap<>();
            response.put("error", "Demasiados intentos fallidos. Operación bloqueada temporalmente por " + remainingMinutes + " minuto(s) por seguridad.");
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(response);
        }

        try {
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

        // Éxito: Limpia contador de intentos fallidos para esta IP y usuario
        loginRateLimiterService.resetAttempts(clientIp, username);

        Usuario usuario = usuarioRepository.findByUsernameIgnoreCase(username)
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));

        if (!usuario.getEstado()) {
            Map<String, String> response = new HashMap<>();
            response.put("error", "El usuario está inactivo o deshabilitado.");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(response);
        }

        if (usuario.getBodega() != null && !Boolean.TRUE.equals(usuario.getBodega().getEstado())) {
            Map<String, String> response = new HashMap<>();
            response.put("error", "La tienda o bodega vinculada a este usuario se encuentra deshabilitada o suspendida.");
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(response);
        }

        Long idBodega = usuario.getBodega() != null ? usuario.getBodega().getIdBodega() : null;
        String planBodega = (usuario.getBodega() != null && usuario.getBodega().getPlan() != null)
                ? usuario.getBodega().getPlan() : "PRO";

        String token = jwtUtil.generateToken(usuario.getUsername(), usuario.getRol(), idBodega, planBodega);

        Map<String, String> response = new HashMap<>();
        response.put("token", token);
        response.put("rol", usuario.getRol());
        response.put("idBodega", idBodega != null ? idBodega.toString() : "");
        response.put("plan", planBodega);
        response.put("email", usuario.getEmail() != null ? usuario.getEmail() : "");

        if (usuario.getBodega() != null) {
            com.bodega.backend.entity.Bodega b = usuario.getBodega();
            response.put("nombreBodega", b.getNombreComercial() != null ? b.getNombreComercial() : "");
            response.put("ruc", b.getRucDni() != null ? b.getRucDni() : "");
            response.put("direccion", b.getDireccion() != null ? b.getDireccion() : "");
            response.put("telefono", b.getTelefono() != null ? b.getTelefono() : "");
            response.put("colorPrimario", b.getColorPrimario() != null ? b.getColorPrimario() : "#2563EB");
            response.put("lemaComercial", b.getLemaComercial() != null ? b.getLemaComercial() : "");
            response.put("logoUrl", b.getLogoUrl() != null ? b.getLogoUrl() : "");
            response.put("regimenTributario", b.getRegimenTributario() != null ? b.getRegimenTributario() : "NUEVO_RUS");
            response.put("giroNegocio", b.getGiroNegocio() != null ? b.getGiroNegocio() : "BODEGA");
            response.put("facturacionSunatActiva", String.valueOf(Boolean.TRUE.equals(b.getFacturacionSunatActiva())));
        } else {
            response.put("nombreBodega", "");
            response.put("colorPrimario", "#2563EB");
            response.put("regimenTributario", "NUEVO_RUS");
            response.put("giroNegocio", "BODEGA");
            response.put("facturacionSunatActiva", "false");
        }

        return ResponseEntity.ok(response);
    }

    @PostMapping("/registrar-bodega")
    public ResponseEntity<Map<String, String>> registrarBodega(@Valid @RequestBody com.bodega.backend.dto.RegistroBodegaDTO dto, HttpServletRequest request) {
        String clientIp = extractClientIp(request);
        String username = dto.getUsername() != null ? dto.getUsername().trim().toLowerCase() : "";

        if (loginRateLimiterService.isBlocked(clientIp, username)) {
            long remaining = loginRateLimiterService.getRemainingBlockMinutes(clientIp, username);
            Map<String, String> err = new HashMap<>();
            err.put("error", "Demasiados intentos. Operación bloqueada temporalmente por " + remaining + " minuto(s).");
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(err);
        }

        if ("admin".equalsIgnoreCase(username) || "superadmin".equalsIgnoreCase(username)) {
            throw new RuntimeException("El nombre de usuario '" + username + "' está reservado por la plataforma. Por favor elija otro identificador (ej. admin_tubodega).");
        }

        if (usuarioRepository.existsByUsernameIgnoreCase(username)) {
            throw new RuntimeException("El nombre de usuario '" + username + "' ya está registrado. Por favor elija otro.");
        }

        // 1. Crear Bodega Tenant
        com.bodega.backend.entity.Bodega bodega = new com.bodega.backend.entity.Bodega();
        bodega.setNombreComercial(dto.getNombreComercial().trim());
        bodega.setRucDni(dto.getRucDni() != null && !dto.getRucDni().isBlank() ? dto.getRucDni().trim() : null);
        bodega.setDireccion(dto.getDireccion() != null && !dto.getDireccion().isBlank() ? dto.getDireccion().trim() : null);
        bodega.setTelefono(dto.getTelefono() != null && !dto.getTelefono().isBlank() ? dto.getTelefono().trim() : null);
        bodega.setColorPrimario(dto.getColorPrimario() != null && !dto.getColorPrimario().isBlank() ? dto.getColorPrimario().trim() : "#2563EB");
        bodega.setLemaComercial(dto.getLemaComercial() != null && !dto.getLemaComercial().isBlank() ? dto.getLemaComercial().trim() : null);
        if (dto.getRegimenTributario() != null && !dto.getRegimenTributario().isBlank()) {
            bodega.setRegimenTributario(dto.getRegimenTributario().trim().toUpperCase());
        } else {
            bodega.setRegimenTributario("NUEVO_RUS");
        }
        if (dto.getGiroNegocio() != null && !dto.getGiroNegocio().isBlank()) {
            bodega.setGiroNegocio(dto.getGiroNegocio().trim().toUpperCase());
        } else {
            bodega.setGiroNegocio("BODEGA");
        }
        // Periodo de prueba gratuito inicial de 1 mes (30 días) con Plan Minimarket PRO completo
        bodega.setPlan("PRO");
        bodega.setEstado(true);
        // Periodo de prueba gratuito de 30 días (1 mes)
        bodega.setFechaVencimientoPlan(java.time.OffsetDateTime.now().plusDays(30));

        com.bodega.backend.entity.Bodega bodegaGuardada = bodegaRepository.save(bodega);

        // 2. Crear Usuario Administrador Dueño
        Usuario admin = new Usuario();
        admin.setUsername(username);
        admin.setPassword(passwordEncoder.encode(dto.getPassword().trim()));
        admin.setNombreCompleto(dto.getNombreComercial().trim());
        admin.setEmail(dto.getEmail() != null && !dto.getEmail().isBlank() ? dto.getEmail().trim().toLowerCase() : null);
        admin.setRol("ADMIN");
        admin.setEstado(true);
        admin.setFechaCambioClave(java.time.OffsetDateTime.now());
        admin.setBodega(bodegaGuardada);
        usuarioRepository.save(admin);

        // 3. Provisionar catálogo estándar y Starter Pack con stock inicial en 0 para que la tienda inicie 100% lista para vender
        starterPackService.provisionarStarterPackParaBodega(bodegaGuardada);

        // 4. Generar Token JWT inicial
        String jwt = jwtUtil.generateToken(admin.getUsername(), admin.getRol(), bodegaGuardada.getIdBodega(), bodegaGuardada.getPlan());

        Map<String, String> response = new HashMap<>();
        response.put("token", jwt);
        response.put("rol", "ADMIN");
        response.put("idBodega", bodegaGuardada.getIdBodega().toString());
        response.put("nombreBodega", bodegaGuardada.getNombreComercial());
        response.put("giroNegocio", bodegaGuardada.getGiroNegocio() != null ? bodegaGuardada.getGiroNegocio() : "BODEGA");
        response.put("plan", bodegaGuardada.getPlan());
        response.put("email", admin.getEmail() != null ? admin.getEmail() : "");
        response.put("ruc", bodegaGuardada.getRucDni() != null ? bodegaGuardada.getRucDni() : "");
        response.put("direccion", bodegaGuardada.getDireccion() != null ? bodegaGuardada.getDireccion() : "");
        response.put("telefono", bodegaGuardada.getTelefono() != null ? bodegaGuardada.getTelefono() : "");
        response.put("colorPrimario", bodegaGuardada.getColorPrimario() != null ? bodegaGuardada.getColorPrimario() : "#2563EB");
        response.put("lemaComercial", bodegaGuardada.getLemaComercial() != null ? bodegaGuardada.getLemaComercial() : "");
        response.put("logoUrl", bodegaGuardada.getLogoUrl() != null ? bodegaGuardada.getLogoUrl() : "");
        response.put("regimenTributario", bodegaGuardada.getRegimenTributario() != null ? bodegaGuardada.getRegimenTributario() : "NUEVO_RUS");
        response.put("facturacionSunatActiva", String.valueOf(Boolean.TRUE.equals(bodegaGuardada.getFacturacionSunatActiva())));
        response.put("mensaje", "¡Bienvenido a CajaYa! Tu tienda '" + bodegaGuardada.getNombreComercial() + "' ha sido creada con éxito. Disfruta de 1 mes gratis de Plan PRO.");
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    // =========================================================================
    // Login Rápido de Cajero en Terminal con PIN Numérico (Aislamiento Multi-tienda)
    // =========================================================================

    @PostMapping("/login-cajero")
    public ResponseEntity<Map<String, String>> loginCajero(
            @Valid @RequestBody com.bodega.backend.dto.LoginCajeroPinDTO dto,
            HttpServletRequest request) {
        String clientIp = extractClientIp(request);
        String rateLimiterKey = "pin_" + (dto.getIdBodega() != null ? dto.getIdBodega() : "anon") + "_" + clientIp;

        if (loginRateLimiterService.isBlocked(clientIp, rateLimiterKey)) {
            long remaining = loginRateLimiterService.getRemainingBlockMinutes(clientIp, rateLimiterKey);
            Map<String, String> err = new HashMap<>();
            err.put("error", "Demasiados intentos con PIN. Operación bloqueada temporalmente por " + remaining + " minuto(s).");
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(err);
        }

        // 1. Identificar la tienda vinculada a la terminal
        com.bodega.backend.entity.Bodega bodega = null;
        if (dto.getIdBodega() != null) {
            bodega = bodegaRepository.findById(dto.getIdBodega()).orElse(null);
        }
        if (bodega == null && dto.getCodigoTienda() != null && !dto.getCodigoTienda().isBlank()) {
            String cod = dto.getCodigoTienda().trim();
            bodega = bodegaRepository.findByRucDni(cod).orElse(null);
            if (bodega == null && cod.matches("^[0-9]+$")) {
                try {
                    bodega = bodegaRepository.findById(Long.parseLong(cod)).orElse(null);
                } catch (Exception ignored) {}
            }
        }

        if (bodega == null) {
            loginRateLimiterService.registerFailedAttempt(clientIp, rateLimiterKey);
            Map<String, String> err = new HashMap<>();
            err.put("error", "Tienda o terminal no identificada. Por favor selecciona o vincula tu local.");
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(err);
        }

        if (!Boolean.TRUE.equals(bodega.getEstado())) {
            Map<String, String> err = new HashMap<>();
            err.put("error", "La tienda vinculada a esta terminal se encuentra deshabilitada o suspendida.");
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(err);
        }

        // 2. Buscar usuario con PIN dentro de esta tienda exclusivamente
        Usuario usuarioAutenticado = null;
        String pinIngresado = dto.getPin().trim();

        if (dto.getIdUsuario() != null) {
            Usuario u = usuarioRepository.findById(dto.getIdUsuario()).orElse(null);
            if (u != null && u.getBodega() != null && bodega.getIdBodega().equals(u.getBodega().getIdBodega()) && Boolean.TRUE.equals(u.getEstado())) {
                boolean match = false;
                if (u.getPin() != null && passwordEncoder.matches(pinIngresado, u.getPin())) {
                    match = true;
                } else if (passwordEncoder.matches(pinIngresado, u.getPassword())) {
                    match = true;
                }
                if (match) {
                    usuarioAutenticado = u;
                }
            }
        } else {
            List<Usuario> usuariosDeTienda = usuarioRepository.findByBodega_IdBodegaAndEstadoTrue(bodega.getIdBodega());
            for (Usuario u : usuariosDeTienda) {
                boolean match = false;
                if (u.getPin() != null && passwordEncoder.matches(pinIngresado, u.getPin())) {
                    match = true;
                } else if (passwordEncoder.matches(pinIngresado, u.getPassword())) {
                    match = true;
                }
                if (match) {
                    usuarioAutenticado = u;
                    break;
                }
            }
        }

        if (usuarioAutenticado == null) {
            loginRateLimiterService.registerFailedAttempt(clientIp, rateLimiterKey);
            Map<String, String> err = new HashMap<>();
            err.put("error", "PIN incorrecto para esta terminal.");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(err);
        }

        // Éxito: limpiar intentos
        loginRateLimiterService.resetAttempts(clientIp, rateLimiterKey);

        Long idBodega = bodega.getIdBodega();
        String planBodega = bodega.getPlan() != null ? bodega.getPlan() : "PRO";
        String token = jwtUtil.generateToken(usuarioAutenticado.getUsername(), usuarioAutenticado.getRol(), idBodega, planBodega);

        Map<String, String> response = new HashMap<>();
        response.put("token", token);
        response.put("rol", usuarioAutenticado.getRol());
        response.put("idBodega", idBodega.toString());
        response.put("nombreBodega", bodega.getNombreComercial() != null ? bodega.getNombreComercial() : "");
        response.put("giroNegocio", bodega.getGiroNegocio() != null ? bodega.getGiroNegocio() : "BODEGA");
        response.put("username", usuarioAutenticado.getUsername());
        response.put("nombreCompleto", usuarioAutenticado.getNombreCompleto() != null ? usuarioAutenticado.getNombreCompleto() : usuarioAutenticado.getUsername());
        response.put("plan", planBodega);
        response.put("email", usuarioAutenticado.getEmail() != null ? usuarioAutenticado.getEmail() : "");
        response.put("ruc", bodega.getRucDni() != null ? bodega.getRucDni() : "");
        response.put("direccion", bodega.getDireccion() != null ? bodega.getDireccion() : "");
        response.put("telefono", bodega.getTelefono() != null ? bodega.getTelefono() : "");
        response.put("colorPrimario", bodega.getColorPrimario() != null ? bodega.getColorPrimario() : "#2563EB");
        response.put("lemaComercial", bodega.getLemaComercial() != null ? bodega.getLemaComercial() : "");
        response.put("logoUrl", bodega.getLogoUrl() != null ? bodega.getLogoUrl() : "");
        response.put("regimenTributario", bodega.getRegimenTributario() != null ? bodega.getRegimenTributario() : "NUEVO_RUS");
        response.put("facturacionSunatActiva", String.valueOf(Boolean.TRUE.equals(bodega.getFacturacionSunatActiva())));
        return ResponseEntity.ok(response);
    }

    @GetMapping("/terminal/{idBodega}/cajeros")
    public ResponseEntity<List<com.bodega.backend.dto.CajeroTerminalDTO>> listarCajerosTerminal(@PathVariable Long idBodega) {
        if (idBodega == null) {
            return ResponseEntity.badRequest().build();
        }
        List<Usuario> usuarios = usuarioRepository.findByBodega_IdBodegaAndEstadoTrue(idBodega);
        List<com.bodega.backend.dto.CajeroTerminalDTO> cajeros = usuarios.stream()
                .filter(u -> !"SUPERADMIN".equalsIgnoreCase(u.getRol()))
                .map(u -> {
                    String nombre = u.getNombreCompleto() != null && !u.getNombreCompleto().isBlank()
                            ? u.getNombreCompleto()
                            : u.getUsername();
                    String[] partes = nombre.trim().split("\\s+");
                    String iniciales = partes.length >= 2
                            ? (partes[0].substring(0, 1) + partes[1].substring(0, 1)).toUpperCase()
                            : nombre.substring(0, Math.min(2, nombre.length())).toUpperCase();
                    return new com.bodega.backend.dto.CajeroTerminalDTO(
                            u.getIdUsuario(),
                            nombre,
                            u.getUsername(),
                            iniciales,
                            u.getRol()
                    );
                })
                .collect(java.util.stream.Collectors.toList());
        return ResponseEntity.ok(cajeros);
    }

    // =========================================================================
    // Endpoints Públicos de Recuperación de Contraseña con Código OTP de 6 Dígitos
    // =========================================================================

    @PostMapping("/recuperar-password/solicitar")
    public ResponseEntity<Map<String, String>> solicitarRecuperacion(
            @Valid @RequestBody SolicitarRecuperacionDTO dto,
            HttpServletRequest request) {
        String clientIp = extractClientIp(request);
        Map<String, String> res = recuperacionClaveService.solicitarCodigo(dto.getIdentificador(), clientIp);
        return ResponseEntity.ok(res);
    }

    @PostMapping("/recuperar-password/verificar")
    public ResponseEntity<Map<String, String>> verificarCodigo(
            @Valid @RequestBody VerificarCodigoDTO dto,
            HttpServletRequest request) {
        String clientIp = extractClientIp(request);
        Map<String, String> res = recuperacionClaveService.verificarCodigo(dto.getIdentificador(), dto.getCodigo(), clientIp);
        return ResponseEntity.ok(res);
    }

    @PostMapping("/recuperar-password/restablecer")
    public ResponseEntity<Map<String, String>> restablecerPassword(
            @Valid @RequestBody RestablecerPasswordDTO dto,
            HttpServletRequest request) {
        String clientIp = extractClientIp(request);
        Map<String, String> res = recuperacionClaveService.restablecerPassword(
                dto.getIdentificador(), dto.getCodigo(), dto.getNuevaPassword(), clientIp);
        return ResponseEntity.ok(res);
    }

    private String extractClientIp(HttpServletRequest request) {
        String xf = request.getHeader("X-Forwarded-For");
        if (xf != null && !xf.isBlank()) {
            String firstIp = xf.split(",")[0].trim();
            if (isValidIp(firstIp)) return firstIp;
        }
        String xr = request.getHeader("X-Real-IP");
        if (xr != null && !xr.isBlank() && isValidIp(xr.trim())) {
            return xr.trim();
        }
        return request.getRemoteAddr() != null ? request.getRemoteAddr().trim() : "127.0.0.1";
    }

    private boolean isValidIp(String ip) {
        if (ip == null || ip.isBlank() || ip.length() > 45) return false;
        // Valida IPv4 estándar o IPv6
        return ip.matches("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$") || ip.contains(":");
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
        userSecurityCacheService.evict(username);

        Map<String, String> response = new HashMap<>();
        response.put("mensaje", "Contraseña actualizada exitosamente.");
        return ResponseEntity.ok(response);
    }
}
