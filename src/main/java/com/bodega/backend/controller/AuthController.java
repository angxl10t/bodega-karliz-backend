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
    private final com.bodega.backend.repository.BodegaRepository bodegaRepository;
    private final com.bodega.backend.repository.CategoriaRepository categoriaRepository;
    private final PasswordEncoder passwordEncoder;
    private final LoginRateLimiterService loginRateLimiterService;
    private final com.bodega.backend.security.UserSecurityCacheService userSecurityCacheService;

    public AuthController(AuthenticationManager authenticationManager, JwtUtil jwtUtil, 
                          UsuarioRepository usuarioRepository,
                          com.bodega.backend.repository.BodegaRepository bodegaRepository,
                          com.bodega.backend.repository.CategoriaRepository categoriaRepository,
                          PasswordEncoder passwordEncoder,
                          LoginRateLimiterService loginRateLimiterService,
                          com.bodega.backend.security.UserSecurityCacheService userSecurityCacheService) {
        this.authenticationManager = authenticationManager;
        this.jwtUtil = jwtUtil;
        this.usuarioRepository = usuarioRepository;
        this.bodegaRepository = bodegaRepository;
        this.categoriaRepository = categoriaRepository;
        this.passwordEncoder = passwordEncoder;
        this.loginRateLimiterService = loginRateLimiterService;
        this.userSecurityCacheService = userSecurityCacheService;
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

        // 4. Genera el JWT con claims de Bodega
        Usuario usuario = usuarioRepository.findByUsernameIgnoreCase(username)
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));
        boolean esSuperAdmin = "SUPERADMIN".equalsIgnoreCase(usuario.getRol());

        Long idBodega;
        String nombreBodega;
        String plan;

        if (esSuperAdmin) {
            idBodega = null;
            nombreBodega = "CajaYa Cloud Platform";
            plan = "SUPERADMIN";
        } else {
            idBodega = (usuario.getBodega() != null) ? usuario.getBodega().getIdBodega() : 1L;
            nombreBodega = (usuario.getBodega() != null && usuario.getBodega().getNombreComercial() != null) 
                    ? usuario.getBodega().getNombreComercial() 
                    : "Bodega KARLIZ";
            plan = (usuario.getBodega() != null && usuario.getBodega().getPlan() != null) 
                    ? usuario.getBodega().getPlan() 
                    : "PRO";
        }

        String jwt = jwtUtil.generateToken(usuario.getUsername(), usuario.getRol(), idBodega, plan);

        // 5. Retorna credenciales y perfil de la tienda al cliente
        Map<String, String> response = new HashMap<>();
        response.put("token", jwt);
        response.put("rol", usuario.getRol());
        response.put("esSuperAdmin", String.valueOf(esSuperAdmin));
        response.put("idBodega", idBodega != null ? idBodega.toString() : "");
        response.put("nombreBodega", nombreBodega);
        response.put("plan", plan);
        if (!esSuperAdmin && usuario.getBodega() != null) {
            response.put("ruc", usuario.getBodega().getRucDni() != null ? usuario.getBodega().getRucDni() : "");
            response.put("direccion", usuario.getBodega().getDireccion() != null ? usuario.getBodega().getDireccion() : "");
            response.put("telefono", usuario.getBodega().getTelefono() != null ? usuario.getBodega().getTelefono() : "");
            response.put("colorPrimario", usuario.getBodega().getColorPrimario() != null ? usuario.getBodega().getColorPrimario() : "#2563EB");
            response.put("lemaComercial", usuario.getBodega().getLemaComercial() != null ? usuario.getBodega().getLemaComercial() : "");
            response.put("logoUrl", usuario.getBodega().getLogoUrl() != null ? usuario.getBodega().getLogoUrl() : "");
            response.put("regimenTributario", usuario.getBodega().getRegimenTributario() != null ? usuario.getBodega().getRegimenTributario() : "NUEVO_RUS");
            response.put("facturacionSunatActiva", String.valueOf(Boolean.TRUE.equals(usuario.getBodega().getFacturacionSunatActiva())));
        } else {
            response.put("colorPrimario", "#8B5CF6");
            response.put("lemaComercial", "Consola Global de Administración de Bodegas");
            response.put("logoUrl", "");
            response.put("regimenTributario", "REGIMEN_GENERAL");
            response.put("facturacionSunatActiva", "true");
        }
        return ResponseEntity.ok(response);
    }

    @PostMapping("/registrar-bodega")
    @org.springframework.transaction.annotation.Transactional
    public ResponseEntity<Map<String, String>> registrarBodega(
            @Valid @RequestBody com.bodega.backend.dto.RegistroBodegaDTO dto,
            HttpServletRequest request) {
        String clientIp = extractClientIp(request);
        String username = dto.getUsername().trim().toLowerCase();

        if (loginRateLimiterService.isBlocked(clientIp, username)) {
            long remaining = loginRateLimiterService.getRemainingBlockMinutes(clientIp, username);
            Map<String, String> err = new HashMap<>();
            err.put("error", "Demasiados intentos. Operación bloqueada temporalmente por " + remaining + " minuto(s).");
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(err);
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
        bodega.setPlan("BASICO");
        bodega.setEstado(true);
        // Periodo de prueba gratuito inicial de 14 días
        bodega.setFechaVencimientoPlan(java.time.OffsetDateTime.now().plusDays(14));

        com.bodega.backend.entity.Bodega bodegaGuardada = bodegaRepository.save(bodega);

        // 2. Crear Usuario Administrador Dueño
        Usuario admin = new Usuario();
        admin.setUsername(username);
        admin.setPassword(passwordEncoder.encode(dto.getPassword().trim()));
        admin.setRol("ADMIN");
        admin.setEstado(true);
        admin.setFechaCambioClave(java.time.OffsetDateTime.now());
        admin.setBodega(bodegaGuardada);
        usuarioRepository.save(admin);

        // 3. Clonar las categorías estándar peruanas para que la nueva tienda inicie lista
        clonarCategoriasMaestras(bodegaGuardada);

        // 4. Generar Token JWT inicial
        String jwt = jwtUtil.generateToken(admin.getUsername(), admin.getRol(), bodegaGuardada.getIdBodega(), bodegaGuardada.getPlan());

        Map<String, String> response = new HashMap<>();
        response.put("token", jwt);
        response.put("rol", "ADMIN");
        response.put("idBodega", bodegaGuardada.getIdBodega().toString());
        response.put("nombreBodega", bodegaGuardada.getNombreComercial());
        response.put("plan", bodegaGuardada.getPlan());
        response.put("ruc", bodegaGuardada.getRucDni() != null ? bodegaGuardada.getRucDni() : "");
        response.put("direccion", bodegaGuardada.getDireccion() != null ? bodegaGuardada.getDireccion() : "");
        response.put("telefono", bodegaGuardada.getTelefono() != null ? bodegaGuardada.getTelefono() : "");
        response.put("colorPrimario", bodegaGuardada.getColorPrimario() != null ? bodegaGuardada.getColorPrimario() : "#2563EB");
        response.put("lemaComercial", bodegaGuardada.getLemaComercial() != null ? bodegaGuardada.getLemaComercial() : "");
        response.put("logoUrl", bodegaGuardada.getLogoUrl() != null ? bodegaGuardada.getLogoUrl() : "");
        response.put("mensaje", "¡Bienvenido a CajaYa! Tu tienda '" + bodegaGuardada.getNombreComercial() + "' ha sido creada con éxito.");
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    private void clonarCategoriasMaestras(com.bodega.backend.entity.Bodega bodega) {
        String[][] categoriasDefault = {
            {"Gaseosas y Bebidas", "Gaseosas, aguas minerales, jugos, energizantes e hidratantes"},
            {"Bebidas Alcohólicas", "Cervezas, piscos, rones, vinos y licores"},
            {"Snacks y Piqueos", "Papas fritas, chizitos, tortillas, platanitos y frutos secos"},
            {"Lácteos y Derivados", "Leche evaporada, fresca, yogures, mantequillas y quesos"},
            {"Embutidos y Fiambrería", "Hot dogs, jamonadas, salchichas, tocinos y embutidos"},
            {"Abarrotes y Fideos", "Arroz, azúcar, fideos, aceites, conservas y condimentos"},
            {"Helados y Postres", "Helados en paleta, conos, bombones y potes familiares"},
            {"Golosinas y Chocolates", "Chocolates, galletas dulces, caramelos y confitería"},
            {"Cuidado Personal y Dental", "Cremas dentales (colinos), jabones, champús y papel"},
            {"Limpieza y Cuidado del Hogar", "Detergentes, lejías, lavavajillas, suavizantes y esponjas"},
            {"Cigarrillos y Tabacos", "Cigarrillos en cajetilla, fósforos y encendedores"},
            {"Panadería y Desayuno", "Pan de molde, mermeladas, café, avena e infusiones"}
        };

        for (String[] catData : categoriasDefault) {
            com.bodega.backend.entity.Categoria cat = new com.bodega.backend.entity.Categoria();
            cat.setNombre(catData[0]);
            cat.setDescripcion(catData[1]);
            cat.setEstado(true);
            cat.setBodega(bodega);
            categoriaRepository.save(cat);
        }
    }

    private String extractClientIp(HttpServletRequest request) {
        // 1. Cabeceras inmutables desde proxy perimetral (Cloudflare / Render Edge)
        String cfIp = request.getHeader("CF-Connecting-IP");
        if (cfIp != null && !cfIp.isBlank() && isValidIp(cfIp.trim())) {
            return cfIp.trim();
        }

        String trueClientIp = request.getHeader("True-Client-IP");
        if (trueClientIp != null && !trueClientIp.isBlank() && isValidIp(trueClientIp.trim())) {
            return trueClientIp.trim();
        }

        String xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isBlank() && isValidIp(xRealIp.trim())) {
            return xRealIp.trim();
        }

        // 2. X-Forwarded-For: Sanitizar y obtener la IP origen válida
        String xf = request.getHeader("X-Forwarded-For");
        if (xf != null && !xf.isBlank()) {
            String[] ips = xf.split(",");
            for (String part : ips) {
                String candidate = part.trim();
                if (isValidIp(candidate)) {
                    return candidate;
                }
            }
        }

        String remote = request.getRemoteAddr();
        return (remote != null && isValidIp(remote)) ? remote : "unknown_ip";
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
