package com.bodega.backend.security;

import java.time.Instant;
import java.time.OffsetDateTime;

/**
 * Perfil inmutable con los atributos de seguridad y branding del usuario en caché.
 */
public class UserSecurityProfile {
    private final String username;
    private final String password;
    private final String rol;
    private final Boolean estado;
    private final OffsetDateTime fechaCambioClave;
    private final Long idBodega;
    private final String nombreBodega;
    private final String plan;
    private final String colorPrimario;
    private final String logoUrl;
    private final String lemaComercial;
    private final Instant cachedAt;

    public UserSecurityProfile(String username, String password, String rol, Boolean estado, OffsetDateTime fechaCambioClave,
                               Long idBodega, String nombreBodega, String plan,
                               String colorPrimario, String logoUrl, String lemaComercial) {
        this.username = username;
        this.password = password;
        this.rol = rol;
        this.estado = estado;
        this.fechaCambioClave = fechaCambioClave;
        this.idBodega = idBodega;
        this.nombreBodega = nombreBodega;
        this.plan = plan;
        this.colorPrimario = (colorPrimario != null && !colorPrimario.isBlank()) ? colorPrimario : "#2563EB";
        this.logoUrl = logoUrl;
        this.lemaComercial = lemaComercial;
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

    public Long getIdBodega() {
        return idBodega;
    }

    public String getNombreBodega() {
        return nombreBodega;
    }

    public String getPlan() {
        return plan;
    }

    public String getColorPrimario() {
        return colorPrimario;
    }

    public String getLogoUrl() {
        return logoUrl;
    }

    public String getLemaComercial() {
        return lemaComercial;
    }

    public boolean isExpired(long ttlSeconds) {
        return Instant.now().isAfter(cachedAt.plusSeconds(ttlSeconds));
    }
}
