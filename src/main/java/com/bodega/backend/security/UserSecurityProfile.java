package com.bodega.backend.security;

import java.time.Instant;
import java.time.OffsetDateTime;

/**
 * Perfil inmutable con los atributos de seguridad del usuario en caché.
 */
public class UserSecurityProfile {
    private final String username;
    private final String password;
    private final String rol;
    private final Boolean estado;
    private final OffsetDateTime fechaCambioClave;
    private final Instant cachedAt;

    public UserSecurityProfile(String username, String password, String rol, Boolean estado, OffsetDateTime fechaCambioClave) {
        this.username = username;
        this.password = password;
        this.rol = rol;
        this.estado = estado;
        this.fechaCambioClave = fechaCambioClave;
        this.cachedAt = Instant.now();
    }

    public String getUsername() {
        return username;
    }

    public String getPassword() {
        return password;
    }

    public String getRol() {
        return rol;
    }

    public Boolean getEstado() {
        return estado;
    }

    public OffsetDateTime getFechaCambioClave() {
        return fechaCambioClave;
    }

    public boolean isExpired(long ttlSeconds) {
        return Instant.now().isAfter(cachedAt.plusSeconds(ttlSeconds));
    }
}
