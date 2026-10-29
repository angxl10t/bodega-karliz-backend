package com.bodega.backend.security;

import jakarta.servlet.http.HttpServletRequest;

/**
 * Utilidad de Extracción y Validación de IP de Cliente.
 * Soporta headers de Cloudflare, Proxies Inversos (Render, AWS, Nginx) y balanceadores.
 */
public final class ClientIpUtil {

    private ClientIpUtil() {}

    public static String extractClientIp(HttpServletRequest request) {
        if (request == null) return "unknown_ip";

        // 1. Headers de Proxies de Confianza y CDN
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

    public static boolean isValidIp(String ip) {
        if (ip == null || ip.isBlank() || ip.length() > 45) return false;
        return ip.matches("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$") || ip.contains(":");
    }
}
