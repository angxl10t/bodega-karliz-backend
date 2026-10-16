package com.bodega.backend.service;

import com.bodega.backend.dto.UsuarioDTO;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.UsuarioRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class UsuarioService {

    private final UsuarioRepository usuarioRepository;
    private final com.bodega.backend.repository.BodegaRepository bodegaRepository;
    private final PasswordEncoder passwordEncoder;
    private final com.bodega.backend.security.UserSecurityCacheService userSecurityCacheService;

    public UsuarioService(UsuarioRepository usuarioRepository, 
                          com.bodega.backend.repository.BodegaRepository bodegaRepository,
                          PasswordEncoder passwordEncoder,
                          com.bodega.backend.security.UserSecurityCacheService userSecurityCacheService) {
        this.usuarioRepository = usuarioRepository;
        this.bodegaRepository = bodegaRepository;
        this.passwordEncoder = passwordEncoder;
        this.userSecurityCacheService = userSecurityCacheService;
    }

    @Transactional(readOnly = true)
    public List<UsuarioDTO> listarTodos() {
        Usuario admin = obtenerUsuarioEnSesion();
        if (admin != null && admin.getBodega() != null) {
            return usuarioRepository.findByBodega_IdBodegaOrderByRolAscUsernameAsc(admin.getBodega().getIdBodega())
                    .stream()
                    .map(this::mapToDTO)
                    .collect(Collectors.toList());
        }
        return usuarioRepository.findAllByOrderByRolAscUsernameAsc().stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public UsuarioDTO crearUsuario(UsuarioDTO dto) {
        String normalizedUsername = dto.getUsername() != null ? dto.getUsername().trim().toLowerCase() : "";
        if (normalizedUsername.isBlank()) {
            throw new RuntimeException("El nombre de usuario no puede estar vacío.");
        }

        if (usuarioRepository.existsByUsernameIgnoreCase(normalizedUsername)) {
            throw new RuntimeException("El nombre de usuario '" + normalizedUsername + "' ya está registrado en el sistema.");
        }

        if (dto.getPassword() == null || dto.getPassword().trim().length() < 8 || dto.getPassword().trim().length() > 72) {
            throw new RuntimeException("La contraseña inicial es obligatoria y debe tener entre 8 y 72 caracteres.");
        }

        String normalizedRol = dto.getRol() != null ? dto.getRol().trim().toUpperCase() : "";
        if (!"ADMIN".equals(normalizedRol) && !"CAJERO".equals(normalizedRol)) {
            throw new RuntimeException("El rol asignado debe ser ADMIN o CAJERO.");
        }

        Usuario admin = obtenerUsuarioEnSesion();
        com.bodega.backend.entity.Bodega bodega = (admin != null && admin.getBodega() != null) ? admin.getBodega() : null;
        if (bodega == null) {
            bodega = bodegaRepository.findById(1L).orElse(null);
        }

        // Feature Gating: En Plan BÁSICO solo se permite 1 usuario administrador (el dueño)
        if (bodega != null) {
            String plan = (bodega.getPlan() != null) ? bodega.getPlan().toUpperCase() : "BASICO";
            if ("BASICO".equals(plan)) {
                long usuariosActivos = usuarioRepository.countByBodega_IdBodegaAndEstadoTrue(bodega.getIdBodega());
                if (usuariosActivos >= 1) {
                    throw new RuntimeException("Tu 'Plan Bodega' incluye 1 usuario administrador. " +
                            "Para habilitar cajeros y empleados con PIN de seguridad, actualiza al 'Plan Minimarket Pro'.");
                }
                if ("CAJERO".equals(normalizedRol)) {
                    throw new RuntimeException("El rol CAJERO no está disponible en el 'Plan Bodega'. " +
                            "Pasa al 'Plan Minimarket Pro' para gestionar personal y turnos.");
                }
            }
        }

        Usuario usuario = new Usuario();
        usuario.setUsername(normalizedUsername);
        usuario.setPassword(passwordEncoder.encode(dto.getPassword().trim()));
        usuario.setRol(normalizedRol);
        usuario.setEstado(true);
        usuario.setFechaCambioClave(OffsetDateTime.now());
        usuario.setBodega(bodega);

        Usuario guardado = usuarioRepository.save(usuario);
        return mapToDTO(guardado);
    }

    @Transactional
    public UsuarioDTO cambiarEstado(Long idUsuario, boolean nuevoEstado, String adminActual) {
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado con ID: " + idUsuario));

        Usuario admin = obtenerUsuarioEnSesion();
        validarMismaBodega(admin, usuario);

        if (!nuevoEstado && usuario.getUsername().equalsIgnoreCase(adminActual)) {
            throw new RuntimeException("No puedes desactivar tu propia cuenta de administrador en sesión.");
        }

        if (!nuevoEstado && "admin".equalsIgnoreCase(usuario.getUsername())) {
            throw new RuntimeException("No se puede desactivar la cuenta administradora raíz del sistema.");
        }

        usuario.setEstado(nuevoEstado);
        usuarioRepository.save(usuario);
        userSecurityCacheService.evict(usuario.getUsername());
        return mapToDTO(usuario);
    }

    @Transactional
    public void resetearPassword(Long idUsuario, String nuevaPassword, String adminActual) {
        if (nuevaPassword == null || nuevaPassword.trim().length() < 8 || nuevaPassword.trim().length() > 72) {
            throw new RuntimeException("La nueva contraseña debe tener entre 8 y 72 caracteres.");
        }

        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado con ID: " + idUsuario));

        Usuario admin = obtenerUsuarioEnSesion();
        validarMismaBodega(admin, usuario);

        // Seguridad de cuenta raíz: solo 'admin' en persona puede restablecer la contraseña de 'admin'
        if ("admin".equalsIgnoreCase(usuario.getUsername()) && !"admin".equalsIgnoreCase(adminActual)) {
            throw new RuntimeException("Solo la cuenta administradora raíz puede restablecer su propia contraseña.");
        }

        usuario.setPassword(passwordEncoder.encode(nuevaPassword.trim()));
        usuario.setFechaCambioClave(OffsetDateTime.now());
        usuarioRepository.save(usuario);
        userSecurityCacheService.evict(usuario.getUsername());
    }

    private Usuario obtenerUsuarioEnSesion() {
        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) {
            return usuarioRepository.findByUsernameIgnoreCase(auth.getName()).orElse(null);
        }
        return null;
    }

    private void validarMismaBodega(Usuario admin, Usuario target) {
        if (admin != null && admin.getBodega() != null && target != null && target.getBodega() != null) {
            if (!admin.getBodega().getIdBodega().equals(target.getBodega().getIdBodega())) {
                throw new org.springframework.security.access.AccessDeniedException(
                        "No tienes permisos para modificar usuarios de otra bodega."
                );
            }
        }
    }

    private UsuarioDTO mapToDTO(Usuario u) {
        UsuarioDTO dto = new UsuarioDTO();
        dto.setIdUsuario(u.getIdUsuario());
        dto.setUsername(u.getUsername());
        dto.setRol(u.getRol());
        dto.setEstado(u.getEstado());
        dto.setFechaCambioClave(u.getFechaCambioClave());
        if (u.getBodega() != null) {
            dto.setIdBodega(u.getBodega().getIdBodega());
            dto.setNombreBodega(u.getBodega().getNombreComercial());
            dto.setPlanBodega(u.getBodega().getPlan());
        }
        return dto;
    }
}
