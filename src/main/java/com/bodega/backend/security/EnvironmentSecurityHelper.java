package com.bodega.backend.security;

import java.util.Map;

/**
 * Utilidad compartida para detectar de manera uniforme si el backend se ejecuta
 * en un entorno de producción (por perfil de Spring o variables de plataforma como Render).
 */
public final class EnvironmentSecurityHelper {

    private EnvironmentSecurityHelper() {
    }

    public static boolean isProduction(String activeProfile) {
        return isProduction(activeProfile, System.getenv());
    }

    static boolean isProduction(String activeProfile, Map<String, String> env) {
        if (activeProfile != null && !activeProfile.isBlank()) {
            String[] profiles = activeProfile.split(",");
            for (String profile : profiles) {
                String trimmed = profile.trim();
                if ("prod".equalsIgnoreCase(trimmed) || "production".equalsIgnoreCase(trimmed)) {
                    return true;
                }
            }
        }
        if (env != null) {
            if ("true".equalsIgnoreCase(env.get("RENDER"))) {
                return true;
            }
            String renderServiceId = env.get("RENDER_SERVICE_ID");
            if (renderServiceId != null && !renderServiceId.isBlank()) {
                return true;
            }
            String environment = env.get("ENVIRONMENT");
            if ("prod".equalsIgnoreCase(environment) || "production".equalsIgnoreCase(environment)) {
                return true;
            }
        }
        return false;
    }
}
