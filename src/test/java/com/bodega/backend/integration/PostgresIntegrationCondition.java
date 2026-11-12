package com.bodega.backend.integration;

import org.junit.jupiter.api.extension.ConditionEvaluationResult;
import org.junit.jupiter.api.extension.ExecutionCondition;
import org.junit.jupiter.api.extension.ExtensionContext;
import org.testcontainers.DockerClientFactory;

/**
 * Habilita la suite de integración PostgreSQL únicamente cuando existe una instancia
 * configurada por variable/propiedad ({@code POSTGRES_TEST_URL} / {@code postgres.test.url})
 * o cuando Docker se encuentra disponible para levantar Testcontainers.
 */
public class PostgresIntegrationCondition implements ExecutionCondition {

    @Override
    public ConditionEvaluationResult evaluateExecutionCondition(ExtensionContext context) {
        if (hasExternalPostgresUrl()) {
            return ConditionEvaluationResult.enabled("PostgreSQL externo configurado vía POSTGRES_TEST_URL.");
        }

        try {
            if (DockerClientFactory.instance().isDockerAvailable()) {
                return ConditionEvaluationResult.enabled("Docker disponible para Testcontainers PostgreSQL.");
            }
        } catch (Throwable ignored) {
            // Entorno sin daemon Docker accesible
        }

        return ConditionEvaluationResult.disabled(
                "Pruebas de integración PostgreSQL omitidas: configura POSTGRES_TEST_URL o inicia Docker para Testcontainers."
        );
    }

    static boolean hasExternalPostgresUrl() {
        String prop = System.getProperty("postgres.test.url");
        if (prop != null && !prop.isBlank()) {
            return true;
        }
        String env = System.getenv("POSTGRES_TEST_URL");
        return env != null && !env.isBlank();
    }
}
