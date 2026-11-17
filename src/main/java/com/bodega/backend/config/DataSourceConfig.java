package com.bodega.backend.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.core.env.Environment;

import javax.sql.DataSource;
import java.net.URI;

@Configuration
public class DataSourceConfig {

    private static final Logger log = LoggerFactory.getLogger(DataSourceConfig.class);

    public static final String DEFAULT_SUPABASE_URL = "jdbc:postgresql://aws-1-us-west-2.pooler.supabase.com:5432/postgres";
    public static final String DEFAULT_SUPABASE_USER = "postgres.rmdbcmnoanyqumjlfphy";

    private final Environment environment;

    public DataSourceConfig(Environment environment) {
        this.environment = environment;
    }

    @Bean
    @Primary
    public DataSource dataSource(
            @Value("${spring.datasource.url:${DB_URL:}}") String configuredUrl,
            @Value("${spring.datasource.username:${DB_USERNAME:}}") String configuredUsername,
            @Value("${spring.datasource.password:${DB_PASSWORD:}}") String configuredPassword) {

        ParsedDbConfig config = resolveDbConfig(configuredUrl, configuredUsername, configuredPassword);

        log.info("[DataSourceConfig] Configurando Hikari DataSource con URL segura: {} y usuario: {}",
                maskJdbcUrl(config.jdbcUrl), config.username);

        HikariConfig hikariConfig = new HikariConfig();
        hikariConfig.setPoolName("CajaYaHikariPool");
        hikariConfig.setDriverClassName("org.postgresql.Driver");
        hikariConfig.setJdbcUrl(config.jdbcUrl);
        hikariConfig.setUsername(config.username);
        hikariConfig.setPassword(config.password);

        // Optimización PgBouncer / Supabase Transaction Pooler
        hikariConfig.setMaximumPoolSize(12);
        hikariConfig.setMinimumIdle(3);
        hikariConfig.setConnectionTimeout(30000);
        hikariConfig.setIdleTimeout(120000);
        hikariConfig.setMaxLifetime(900000);
        hikariConfig.setLeakDetectionThreshold(60000);
        hikariConfig.setKeepaliveTime(30000);
        hikariConfig.setConnectionTestQuery("SELECT 1");
        hikariConfig.setValidationTimeout(5000);

        hikariConfig.addDataSourceProperty("prepareThreshold", "0");
        hikariConfig.addDataSourceProperty("preparedStatementCacheQueries", "0");
        hikariConfig.addDataSourceProperty("tcpKeepAlive", "true");

        return new HikariDataSource(hikariConfig);
    }

    ParsedDbConfig resolveDbConfig(String configuredUrl, String configuredUsername, String configuredPassword) {
        String rawUrl = configuredUrl;
        if (rawUrl == null || rawUrl.isBlank()) {
            rawUrl = environment.getProperty("DB_URL");
        }
        if (rawUrl == null || rawUrl.isBlank()) {
            rawUrl = environment.getProperty("DATABASE_URL");
        }
        if (rawUrl == null || rawUrl.isBlank()) {
            rawUrl = environment.getProperty("SPRING_DATASOURCE_URL");
        }

        String username = configuredUsername;
        if (username == null || username.isBlank()) {
            username = environment.getProperty("DB_USERNAME");
        }
        if (username == null || username.isBlank()) {
            username = environment.getProperty("SPRING_DATASOURCE_USERNAME");
        }
        if (username == null || username.isBlank()) {
            username = environment.getProperty("DATABASE_USERNAME");
        }

        String password = configuredPassword;
        if (password == null || password.isBlank()) {
            password = environment.getProperty("DB_PASSWORD");
        }
        if (password == null || password.isBlank()) {
            password = environment.getProperty("SPRING_DATASOURCE_PASSWORD");
        }
        if (password == null || password.isBlank()) {
            password = environment.getProperty("DATABASE_PASSWORD");
        }

        String jdbcUrl = rawUrl != null ? rawUrl.trim() : "";

        // Si la URL viene con credenciales integradas en formato URI estándar (ej. postgres://user:pass@host:port/db)
        if (jdbcUrl.contains("@")) {
            try {
                String uriString = jdbcUrl.startsWith("jdbc:") ? jdbcUrl.substring(5) : jdbcUrl;
                URI uri = URI.create(uriString);
                String userInfo = uri.getUserInfo();
                if (userInfo != null && !userInfo.isBlank()) {
                    String[] userParts = userInfo.split(":", 2);
                    if (userParts.length > 0 && !userParts[0].isBlank() && (username == null || username.isBlank())) {
                        username = userParts[0];
                    }
                    if (userParts.length > 1 && !userParts[1].isBlank() && (password == null || password.isBlank())) {
                        password = userParts[1];
                    }
                }
                int port = uri.getPort() > 0 ? uri.getPort() : 5432;
                String path = uri.getPath() != null && !uri.getPath().isBlank() ? uri.getPath() : "/postgres";
                String query = uri.getQuery() != null && !uri.getQuery().isBlank() ? "?" + uri.getQuery() : "";
                jdbcUrl = "jdbc:postgresql://" + uri.getHost() + ":" + port + path + query;
            } catch (Exception e) {
                log.warn("[DataSourceConfig] No se pudo analizar userInfo de URI: {}", e.getMessage());
            }
        }

        // Normalizar prefijo JDBC
        if (jdbcUrl.startsWith("postgres://")) {
            jdbcUrl = "jdbc:postgresql://" + jdbcUrl.substring("postgres://".length());
        } else if (jdbcUrl.startsWith("postgresql://")) {
            jdbcUrl = "jdbc:postgresql://" + jdbcUrl.substring("postgresql://".length());
        } else if (!jdbcUrl.startsWith("jdbc:postgresql://") && !jdbcUrl.isBlank() && !jdbcUrl.startsWith("jdbc:")) {
            jdbcUrl = "jdbc:postgresql://" + jdbcUrl;
        }

        // Detección de entorno en la nube vs entorno local/CI
        boolean isCi = "true".equalsIgnoreCase(environment.getProperty("CI"))
                || "true".equalsIgnoreCase(environment.getProperty("GITHUB_ACTIONS"));
        boolean isCloudContainer = (environment.getProperty("RENDER") != null
                || environment.getProperty("RENDER_SERVICE_ID") != null
                || "production".equalsIgnoreCase(environment.getProperty("ENVIRONMENT"))
                || "prod".equalsIgnoreCase(environment.getProperty("SPRING_PROFILES_ACTIVE"))
                || (environment.getProperty("PORT") != null && !isCi));

        // Si la URL está vacía o si en un contenedor cloud apunta a localhost/127.0.0.1
        if (jdbcUrl.isBlank() || (isCloudContainer && !isCi && (jdbcUrl.contains("localhost") || jdbcUrl.contains("127.0.0.1")))) {
            if (!jdbcUrl.isBlank()) {
                log.error("[DataSourceConfig] ¡ALERTA! Se detectó conexión a localhost ('{}') en contenedor Render/Cloud. " +
                        "Reemplazando automáticamente por Supabase Pooler oficial para evitar crash de arranque.", jdbcUrl);
            } else {
                log.info("[DataSourceConfig] URL no especificada. Usando Supabase Pooler oficial por defecto.");
            }
            jdbcUrl = DEFAULT_SUPABASE_URL;
        }

        if (username == null || username.isBlank()) {
            username = DEFAULT_SUPABASE_USER;
        }
        if (password == null) {
            password = "";
        }

        return new ParsedDbConfig(jdbcUrl, username, password);
    }

    private String maskJdbcUrl(String url) {
        if (url == null) return "null";
        return url.replaceAll(":[^/@:]+@", ":****@");
    }

    public static class ParsedDbConfig {
        public final String jdbcUrl;
        public final String username;
        public final String password;

        public ParsedDbConfig(String jdbcUrl, String username, String password) {
            this.jdbcUrl = jdbcUrl;
            this.username = username;
            this.password = password;
        }
    }
}
