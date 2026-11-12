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
        registry.add("spring.jpa.open-in-view", () -> "false");
        registry.add("spring.jpa.properties.hibernate.dialect", () -> "org.hibernate.dialect.PostgreSQLDialect");
        registry.add("spring.sql.init.mode", () -> "never");
        registry.add("cajaya.migrations.enabled", () -> "true");
        registry.add("cajaya.migrations.continue-on-error", () -> "true");
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
