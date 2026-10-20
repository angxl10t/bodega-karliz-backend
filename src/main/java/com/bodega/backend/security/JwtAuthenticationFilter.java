package com.bodega.backend.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Date;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final UserSecurityCacheService userSecurityCacheService;

    public JwtAuthenticationFilter(JwtUtil jwtUtil, 
                                   UserSecurityCacheService userSecurityCacheService) {
        this.jwtUtil = jwtUtil;
        this.userSecurityCacheService = userSecurityCacheService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {

        final String authorizationHeader = request.getHeader("Authorization");

        io.jsonwebtoken.Claims claims = null;
        String username = null;

        if (authorizationHeader != null && authorizationHeader.regionMatches(true, 0, "Bearer ", 0, 7)) {
            String jwt = authorizationHeader.substring(7).trim();
            if (!jwt.isEmpty()) {
                try {
                    claims = jwtUtil.extractAllClaims(jwt);
                    username = claims.getSubject();
                } catch (Exception e) {
                    // Token inválido, expirado o con firma incorrecta
                }
            }
        }

        if (username != null && claims != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            UserSecurityProfile usuario = userSecurityCacheService.getSecurityProfile(username).orElse(null);

            boolean esSuperAdmin = usuario != null && "SUPERADMIN".equalsIgnoreCase(usuario.getRol());
            boolean bodegaActiva = esSuperAdmin || usuario == null || usuario.getEstadoBodega() == null || Boolean.TRUE.equals(usuario.getEstadoBodega());

            if (usuario != null && Boolean.TRUE.equals(usuario.getEstado()) && bodegaActiva 
                    && username.equalsIgnoreCase(usuario.getUsername())) {
                // Validación de revocación de sesión: si la contraseña cambió luego de emitir el token, se invalida
                Date issuedAt = claims.getIssuedAt();
                boolean tokenRevocado = false;

                if (usuario.getFechaCambioClave() != null && issuedAt != null) {
                    long issuedMillis = issuedAt.getTime();
                    long passwordChangeMillis = usuario.getFechaCambioClave().toInstant().toEpochMilli();
                    // Margen de 1 segundo de tolerancia de sincronización de reloj
                    if (issuedMillis < (passwordChangeMillis - 1000)) {
                        tokenRevocado = true;
                    }
                }

                if (!tokenRevocado) {
                    UserDetails userDetails = User.builder()
                            .username(usuario.getUsername())
                            .password(usuario.getPassword())
                            .roles(usuario.getRol())
                            .build();

                    UsernamePasswordAuthenticationToken authToken = new UsernamePasswordAuthenticationToken(
                            userDetails, null, userDetails.getAuthorities());
                    authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(authToken);
                }
            }
        }
        chain.doFilter(request, response);
    }
}
