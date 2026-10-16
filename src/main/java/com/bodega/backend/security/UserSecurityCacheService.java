package com.bodega.backend.security;

import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.UsuarioRepository;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Caché en memoria de perfiles de seguridad para prevenir la saturación
 * del pool de conexiones HikariCP en JwtAuthenticationFilter.
 */
@Service
public class UserSecurityCacheService {

    private static final long CACHE_TTL_SECONDS = 60; // 60 segundos de persistencia en memoria
    private final ConcurrentHashMap<String, UserSecurityProfile> cache = new ConcurrentHashMap<>();
    private final UsuarioRepository usuarioRepository;
    private Instant lastPurge = Instant.now();

    public UserSecurityCacheService(UsuarioRepository usuarioRepository) {
        this.usuarioRepository = usuarioRepository;
    }

    /**
     * Obtiene el perfil de seguridad del usuario desde la caché en memoria.
     * Si no existe o expiró, consulta la base de datos y refresca la caché.
     */
    public Optional<UserSecurityProfile> getSecurityProfile(String username) {
        if (username == null || username.isBlank()) {
            return Optional.empty();
        }

        String key = username.trim().toLowerCase();
        UserSecurityProfile profile = cache.get(key);

        if (profile != null && !profile.isExpired(CACHE_TTL_SECONDS)) {
            return Optional.of(profile);
        }

        // Si expiró o no existe en caché, consultar BD de forma segura
        Optional<Usuario> usuarioOpt = usuarioRepository.findByUsernameIgnoreCase(key);
        if (usuarioOpt.isPresent()) {
            Usuario u = usuarioOpt.get();
            UserSecurityProfile nuevo = new UserSecurityProfile(
                    u.getUsername(),
                    u.getPassword(),
                    u.getRol(),
                    u.getEstado(),
                    u.getFechaCambioClave()
            );
            cache.put(key, nuevo);
            purgeExpiredIfNeeded();
            return Optional.of(nuevo);
        } else {
            cache.remove(key);
            return Optional.empty();
        }
    }

    /**
     * Invalida inmediatamente la entrada de un usuario en caché (ej. al cambiar clave,
     * desactivar cuenta o resetear contraseña).
     */
    public void evict(String username) {
        if (username != null && !username.isBlank()) {
            cache.remove(username.trim().toLowerCase());
        }
    }

    /**
     * Invalida toda la memoria de perfiles.
     */
    public void evictAll() {
        cache.clear();
    }

    private void purgeExpiredIfNeeded() {
        Instant now = Instant.now();
        if (now.isAfter(lastPurge.plusSeconds(300))) { // Limpieza periódica cada 5 minutos
            cache.entrySet().removeIf(entry -> entry.getValue().isExpired(CACHE_TTL_SECONDS));
            lastPurge = now;
        }
    }
}
