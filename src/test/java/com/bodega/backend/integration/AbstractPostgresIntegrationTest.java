package com.bodega.backend.integration;

import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.postgresql.PostgreSQLContainer;

/**
 * Clase base para pruebas de integración reales contra PostgreSQL 16.
 * Soporta tanto {@code POSTGRES_TEST_URL} (usado en GitHub Actions con service container)
 * como {@link PostgreSQLContainer} automático vía Testcontainers.
 */
@ExtendWith(PostgresIntegrationCondition.class)
@SpringBootTest
public abstract class AbstractPostgresIntegrationTest {

    private static volatile PostgreSQLContainer postgresContainer;

    private static PostgreSQLContainer getOrStartContainer() {
        if (postgresContainer == null) {
            synchronized (AbstractPostgresIntegrationTest.class) {
                if (postgresContainer == null) {
                    PostgreSQLContainer container = new PostgreSQLContainer("postgres:16-alpine")
                            .withDatabaseName("cajaya_test")
                            .withUsername("cajaya_test")
                            .withPassword("cajaya_test_password");
                    container.start();
                    postgresContainer = container;
                }
            }
        }
        return postgresContainer;
    }

    @DynamicPropertySource
    static void registerPostgresProperties(DynamicPropertyRegistry registry) {
        if (PostgresIntegrationCondition.hasExternalPostgresUrl()) {
            String url = firstNonBlank(System.getProperty("postgres.test.url"), System.getenv("POSTGRES_TEST_URL"));
            String user = firstNonBlank(System.getProperty("postgres.test.user"), System.getenv("POSTGRES_TEST_USER"), "cajaya_test");
            String pass = firstNonBlank(System.getProperty("postgres.test.password"), System.getenv("POSTGRES_TEST_PASSWORD"), "cajaya_test_password");
            registry.add("spring.datasource.url", () -> url);
            registry.add("spring.datasource.username", () -> user);
            registry.add("spring.datasource.password", () -> pass);
        } else {
            PostgreSQLContainer container = getOrStartContainer();
            registry.add("spring.datasource.url", container::getJdbcUrl);
            registry.add("spring.datasource.username", container::getUsername);
            registry.add("spring.datasource.password", container::getPassword);
        }

        registry.add("spring.jpa.hibernate.ddl-auto", () -> "update");
        registry.add("spring.jpa.defer-datasource-initialization", () -> "true");
        registry.add("spring.jpa.open-in-view", () -> "false");
        registry.add("spring.jpa.properties.hibernate.dialect", () -> "org.hibernate.dialect.PostgreSQLDialect");
        registry.add("spring.sql.init.mode", () -> "always");
        registry.add("spring.sql.init.continue-on-error", () -> "true");
        registry.add("spring.sql.init.schema-locations", () -> String.join(",",
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
        ));
        registry.add("jwt.secret", () -> "TestIntegrationJwtSecretKey_256Bits_CajaYa_2026_Valid!");
        registry.add("cajaya.yape.webhook-secret", () -> "TestIntegrationYapeWebhookSecret_2026_CajaYa");
        registry.add("cajaya.security.superadmin-password", () -> "IntegrationAdmin#2026");
        registry.add("cajaya.seed.demo-accounts", () -> "false");
    }

    private static String firstNonBlank(String... candidates) {
        for (String c : candidates) {
            if (c != null && !c.isBlank()) {
                return c.trim();
            }
        }
        return "";
    }
}
