package com.bodega.backend.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.List;
import java.util.Locale;

/**
 * Ejecuta las migraciones PostgreSQL declaradas en {@code cajaya.migrations.locations}
 * después de Hibernate {@code ddl-auto} y antes de {@link DataInitializer}, respetando
 * bloques PL/pgSQL con dollar-quoting ({@code $$ ... $$}) que {@code ScriptUtils} de Spring
 * fragmentaría erróneamente.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class PostgresMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(PostgresMigrationRunner.class);

    private final DataSource dataSource;
    private final ResourceLoader resourceLoader;
    private final boolean enabled;
    private final boolean continueOnError;
    private final List<String> locations;

    public PostgresMigrationRunner(
            DataSource dataSource,
            ResourceLoader resourceLoader,
            @Value("${cajaya.migrations.enabled:true}") boolean enabled,
            @Value("${cajaya.migrations.continue-on-error:true}") boolean continueOnError,
            @Value("${cajaya.migrations.locations:}") List<String> locations) {
        this.dataSource = dataSource;
        this.resourceLoader = resourceLoader;
        this.enabled = enabled;
        this.continueOnError = continueOnError;
        this.locations = locations != null ? locations : List.of();
    }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        if (!enabled || locations.isEmpty()) {
            log.debug("[PostgresMigrationRunner] Migraciones SQL deshabilitadas o sin scripts configurados.");
            return;
        }

        try (Connection connection = dataSource.getConnection()) {
            String productName = connection.getMetaData().getDatabaseProductName();
            if (productName == null || !productName.toLowerCase(Locale.ROOT).contains("postgresql")) {
                log.info("[PostgresMigrationRunner] Motor '{}' detectado; se omiten scripts exclusivos de PostgreSQL.", productName);
                return;
            }

            if (!connection.getAutoCommit()) {
                connection.setAutoCommit(true);
            }

            int scriptsExecuted = 0;
            int statementsExecuted = 0;
            int warnings = 0;

            for (String rawLocation : locations) {
                String location = rawLocation == null ? "" : rawLocation.trim();
                if (location.isEmpty()) {
                    continue;
                }

                Resource resource = resourceLoader.getResource(location);
                if (!resource.exists()) {
                    String msg = "Script de migración no encontrado: " + location;
                    if (continueOnError) {
                        log.warn("[PostgresMigrationRunner] {}", msg);
                        warnings++;
                        continue;
                    }
                    throw new IllegalStateException(msg);
                }

                String sql = readUtf8(resource);
                List<String> statements = DollarQuotedSqlSplitter.splitStatements(sql);
                scriptsExecuted++;

                try (Statement stmt = connection.createStatement()) {
                    for (String sqlStatement : statements) {
                        try {
                            stmt.execute(sqlStatement);
                            statementsExecuted++;
                        } catch (SQLException ex) {
                            warnings++;
                            String preview = sqlStatement.replaceAll("\\s+", " ");
                            if (preview.length() > 140) {
                                preview = preview.substring(0, 140) + "...";
                            }
                            if (!continueOnError) {
                                throw new IllegalStateException(
                                        "Fallo ejecutando sentencia en " + location + " [" + preview + "]: " + ex.getMessage(),
                                        ex
                                );
                            }
                            log.warn("[PostgresMigrationRunner] Aviso idempotente en {} ({}): {}",
                                    location, ex.getSQLState(), ex.getMessage());
                        }
                    }
                }
            }

            log.info("[PostgresMigrationRunner] {} scripts PostgreSQL procesados ({} sentencias ejecutadas, {} avisos idempotentes).",
                    scriptsExecuted, statementsExecuted, warnings);
        }
    }

    private static String readUtf8(Resource resource) throws IOException {
        return new String(resource.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
    }
}
