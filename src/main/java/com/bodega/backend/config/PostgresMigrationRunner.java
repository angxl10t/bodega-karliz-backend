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
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

/**
 * Ejecuta las migraciones PostgreSQL declaradas en {@code cajaya.migrations.locations}
 * (o {@link #DEFAULT_MIGRATION_LOCATIONS} por defecto) después de Hibernate {@code ddl-auto}
 * y antes de {@link DataInitializer}, respetando bloques PL/pgSQL con dollar-quoting
 * ({@code $$ ... $$}) que {@code ScriptUtils} de Spring fragmentaría erróneamente.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class PostgresMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(PostgresMigrationRunner.class);

    // Nota: v23_update_real_bodega_street_prices.sql se excluye del arranque para no sobrescribir tarifas personalizadas de cada bodega.
    public static final List<String> DEFAULT_MIGRATION_LOCATIONS = List.of(
            "classpath:db/migration/v1_multitenant_schema.sql",
            "classpath:db/migration/v2_rls_and_refinement.sql",
            "classpath:db/migration/v3_scalability_and_performance.sql",
            "classpath:db/migration/v4_enterprise_subscriptions_and_integrity.sql",
            "classpath:db/migration/v5_sunat_regimen_and_documents.sql",
            "classpath:db/migration/v6_sunat_emission_fields.sql",
            "classpath:db/migration/v7_nuevo_rus_and_integrity_alignment.sql",
            "classpath:db/migration/v8_multitenant_indexes.sql",
            "classpath:db/migration/v9_caja_chica_and_arqueo.sql",
            "classpath:db/migration/v10_performance_optimizations.sql",
            "classpath:db/migration/v11_producto_imagen_url.sql",
            "classpath:db/migration/v12_control_inventario_y_mermas.sql",
            "classpath:db/migration/v13_resilience_and_performance_tuning.sql",
            "classpath:db/migration/v14_enable_rls_all_tables.sql",
            "classpath:db/migration/v18_sanitize_categories_and_starter_pack.sql",
            "classpath:db/migration/v19_drop_legacy_single_tenant_constraints.sql",
            "classpath:db/migration/v20_garantias_botellas.sql",
            "classpath:db/migration/v21_promociones_and_discounts.sql",
            "classpath:db/migration/v22_pedidos_web.sql",
            "classpath:db/migration/v24_boletas_consolidadas_nuevo_rus.sql",
            "classpath:db/migration/v24_libro_reclamaciones_and_viralidad.sql",
            "classpath:db/migration/v25_usuario_email_and_password_recovery.sql",
            "classpath:db/migration/v26_admin_cajayapos_email.sql",
            "classpath:db/migration/v27_logic_and_performance_fixes.sql"
    );

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
            @Value("${cajaya.migrations.locations:}") String rawLocations) {
        this.dataSource = dataSource;
        this.resourceLoader = resourceLoader;
        this.enabled = enabled;
        this.continueOnError = continueOnError;
        List<String> parsed = parseLocations(rawLocations);
        this.locations = parsed.isEmpty() ? DEFAULT_MIGRATION_LOCATIONS : parsed;
    }

    static List<String> parseLocations(String rawLocations) {
        if (rawLocations == null || rawLocations.isBlank()) {
            return List.of();
        }
        return Arrays.stream(rawLocations.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .toList();
    }

    List<String> getLocations() {
        return locations;
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

            for (String location : locations) {
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
