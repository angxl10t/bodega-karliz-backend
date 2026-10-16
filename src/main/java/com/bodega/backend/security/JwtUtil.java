package com.bodega.backend.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Component;

import java.security.Key;
import java.util.Date;
import java.util.function.Function;

@Component
public class JwtUtil {

    @org.springframework.beans.factory.annotation.Value("${jwt.secret:}")
    private String secretKey;

    @jakarta.annotation.PostConstruct
    public void validateSecret() {
        if (secretKey == null || secretKey.trim().length() < 32) {
            throw new IllegalStateException(
                "CRITICAL SECURITY CONFIGURATION ERROR: La variable de entorno JWT_SECRET no está configurada o tiene menos de 256 bits (mínimo 32 caracteres)."
            );
        }
    }

    private Key getSigningKey() {
        return Keys.hmacShaKeyFor(secretKey.getBytes(java.nio.charset.StandardCharsets.UTF_8));
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

    private Claims extractAllClaims(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJws(token)
                .getBody();
    }

    private Boolean isTokenExpired(String token) {
        return extractExpiration(token).before(new Date());
    }

    @org.springframework.beans.factory.annotation.Value("${jwt.expiration-ms:86400000}")
    private long expirationMs;

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
        final String extractedUsername = extractUsername(token);
        return (extractedUsername != null && extractedUsername.equalsIgnoreCase(username) && !isTokenExpired(token));
    }
}
