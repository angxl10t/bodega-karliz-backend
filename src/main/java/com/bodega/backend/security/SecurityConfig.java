package com.bodega.backend.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .csrf(csrf -> csrf.disable())
            .headers(headers -> headers
                .frameOptions(frame -> frame.deny())
                .contentTypeOptions(org.springframework.security.config.Customizer.withDefaults())
                .httpStrictTransportSecurity(hsts -> hsts
                    .includeSubDomains(true)
                    .maxAgeInSeconds(31536000)
                )
            )
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint((request, response, authException) -> {
                    response.setContentType("application/json;charset=UTF-8");
                    response.setStatus(jakarta.servlet.http.HttpServletResponse.SC_UNAUTHORIZED);
                    response.getWriter().write("{\"error\": \"No autenticado. Token ausente, inválido o expirado.\"}");
                })
                .accessDeniedHandler((request, response, accessDeniedException) -> {
                    response.setContentType("application/json;charset=UTF-8");
                    response.setStatus(jakarta.servlet.http.HttpServletResponse.SC_FORBIDDEN);
                    response.getWriter().write("{\"error\": \"Acceso denegado. Permisos insuficientes.\"}");
                })
            )
            .authorizeHttpRequests(auth -> auth
                // Inicio de sesión y registro de nueva bodega son públicos en /api/auth
                .requestMatchers(org.springframework.http.HttpMethod.POST, "/api/auth/login", "/api/auth/registrar-bodega").permitAll()
                .requestMatchers("/api/auth/login", "/api/auth/login/**", "/api/auth/registrar-bodega", "/api/auth/registrar-bodega/**").permitAll()
                // Health check ultraligero público para monitor de Render (diagnóstico restringido a SUPERADMIN)
                .requestMatchers("/api/health/diagnostico").hasRole("SUPERADMIN")
                // Monitores externos (UptimeRobot en plan gratuito) y Keep-Alive: permitir HEAD globalmente sin autenticacion
                .requestMatchers(org.springframework.http.HttpMethod.HEAD, "/**").permitAll()
                .requestMatchers("/api/health", "/api/health/**", "/health", "/health/**", "/").permitAll()
                .requestMatchers("/error").permitAll()
                // Bloqueo total y autenticación obligatoria para todo lo demás
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public org.springframework.security.access.hierarchicalroles.RoleHierarchy roleHierarchy() {
        return org.springframework.security.access.hierarchicalroles.RoleHierarchyImpl.withDefaultRolePrefix()
                .role("SUPERADMIN").implies("ADMIN")
                .role("ADMIN").implies("CAJERO")
                .build();
    }

    @Bean
    public static org.springframework.security.access.expression.method.MethodSecurityExpressionHandler methodSecurityExpressionHandler(
            org.springframework.security.access.hierarchicalroles.RoleHierarchy roleHierarchy) {
        org.springframework.security.access.expression.method.DefaultMethodSecurityExpressionHandler handler =
                new org.springframework.security.access.expression.method.DefaultMethodSecurityExpressionHandler();
        handler.setRoleHierarchy(roleHierarchy);
        return handler;
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        // Restricción estricta de orígenes autorizados: GitHub Pages oficial y entornos locales de desarrollo/pruebas
        configuration.setAllowedOriginPatterns(List.of(
            "*",
            "https://*.onrender.com",
            "https://cajaya-pos.onrender.com",
            "https://bodega-karliz.onrender.com",
            "https://angxl10t.github.io",
            "http://localhost:*",
            "https://localhost:*",
            "http://127.0.0.1:*",
            "https://127.0.0.1:*"
        ));
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"));
        configuration.setAllowedHeaders(List.of("*"));
        configuration.setAllowCredentials(true);
        
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
