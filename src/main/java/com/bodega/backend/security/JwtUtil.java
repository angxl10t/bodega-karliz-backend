package com.bodega.backend.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.security.Key;
import java.util.Date;
import java.util.function.Function;

@Component
public class JwtUtil {

    private static final Logger log = LoggerFactory.getLogger(JwtUtil.class);

    public static final String DEFAULT_DEV_SECRET = "404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970";

    @Value("${jwt.secret:}")
    private String secretKey;

    @Value("${spring.profiles.active:default}")
    private String activeProfile;

    @Value("${jwt.expiration-ms:86400000}")
    private long expirationMs;

    private Key signingKey;

    @PostConstruct
    public void validateSecret() {
        if (secretKey == null || secretKey.trim().length() < 32) {
            throw new IllegalStateException(
                "CRITICAL SECURITY CONFIGURATION ERROR: La variable de entorno JWT_SECRET no está configurada o tiene menos de 256 bits (mínimo 32 caracteres)."
            );
        }

        boolean isProduction = EnvironmentSecurityHelper.isProduction(activeProfile);

        if (isProduction && DEFAULT_DEV_SECRET.equals(secretKey.trim())) {
            throw new IllegalStateException(
                "CRITICAL SECURITY CONFIGURATION ERROR: Se detectó el uso de la clave JWT por defecto en entorno de producción. " +
                "Debe configurar una variable de entorno JWT_SECRET única y de alta entropía para proteger el sistema."
            );
        } else if (DEFAULT_DEV_SECRET.equals(secretKey.trim())) {
            log.warn(
                "[SECURITY ADVISORY] Se está ejecutando con la clave JWT por defecto. " +
                "Asegúrese de establecer la variable de entorno JWT_SECRET antes de desplegar en producción."
            );
        }

        this.signingKey = Keys.hmacShaKeyFor(secretKey.trim().getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    private Key getSigningKey() {
        return this.signingKey;
    }

    public String extractUsername(String token) {
        return extractClaim(token, Claims::getSubject);
    }

    public Date extractExpiration(String token) {
        return extractClaim(token, Claims::getExpiration);
    }

    public Date extractIssuedAt(String token) {
        return extractClaim(token, Claims::getIssuedAt);
    }

    public <T> T extractClaim(String token, Function<Claims, T> claimsResolver) {
        final Claims claims = extractAllClaims(token);
        return claimsResolver.apply(claims);
    }

    public Claims extractAllClaims(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .setAllowedClockSkewSeconds(60) // Tolerancia de 60 segundos ante desvíos de reloj en clientes móviles y servidores
                .build()
                .parseClaimsJws(token)
                .getBody();
    }

    private Boolean isTokenExpired(String token) {
        return extractExpiration(token).before(new Date());
    }

    public String generateToken(String username, String rol) {
        return generateToken(username, rol, 1L, "PRO");
    }

    public String generateToken(String username, String rol, Long idBodega, String plan) {
        return Jwts.builder()
                .setSubject(username)
                .claim("rol", rol)
                .claim("idBodega", idBodega != null ? idBodega : 0L)
                .claim("plan", plan != null ? plan : "BASICO")
                .setIssuedAt(new Date(System.currentTimeMillis()))
                // Expira en 24 horas (recomendado para turnos comerciales completos en POS)
                .setExpiration(new Date(System.currentTimeMillis() + expirationMs)) 
                .signWith(getSigningKey(), SignatureAlgorithm.HS256)
                .compact();
    }

    public Boolean validateToken(String token, String username) {
        if (token == null || token.isBlank() || username == null || username.isBlank()) {
            return false;
        }
        try {
            Claims claims = extractAllClaims(token);
            String extractedUsername = claims.getSubject();
            Date expiration = claims.getExpiration();
            return (extractedUsername != null && extractedUsername.equalsIgnoreCase(username.trim())
                    && (expiration == null || !expiration.before(new Date())));
        } catch (Exception e) {
            return false;
        }
    }
}
