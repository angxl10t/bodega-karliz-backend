package com.bodega.backend.security;

import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.UsuarioRepository;
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
    private final UsuarioRepository usuarioRepository;

    public JwtAuthenticationFilter(JwtUtil jwtUtil, 
                                   UsuarioRepository usuarioRepository) {
        this.jwtUtil = jwtUtil;
        this.usuarioRepository = usuarioRepository;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {

        final String authorizationHeader = request.getHeader("Authorization");

        String username = null;
        String jwt = null;

        if (authorizationHeader != null && authorizationHeader.startsWith("Bearer ")) {
            jwt = authorizationHeader.substring(7);
            try {
                username = jwtUtil.extractUsername(jwt);
            } catch (Exception e) {
                // Token inválido o expirado
            }
        }

        if (username != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            Usuario usuario = usuarioRepository.findByUsernameIgnoreCase(username).orElse(null);

            if (usuario != null && Boolean.TRUE.equals(usuario.getEstado()) && jwtUtil.validateToken(jwt, usuario.getUsername())) {
                // Validación de revocación de sesión: si la contraseña cambió luego de emitir el token, se invalida
                Date issuedAt = jwtUtil.extractIssuedAt(jwt);
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
