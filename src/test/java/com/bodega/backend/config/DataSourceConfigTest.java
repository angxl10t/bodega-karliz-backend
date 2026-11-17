package com.bodega.backend.config;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

import static org.junit.jupiter.api.Assertions.*;

class DataSourceConfigTest {

    @Test
    void testResolveValidUrl_DefaultSupabasePoolerWhenEmpty() {
        MockEnvironment env = new MockEnvironment();
        DataSourceConfig config = new DataSourceConfig(env);

        DataSourceConfig.ParsedDbConfig parsed = config.resolveDbConfig("", "", "");

        assertEquals(DataSourceConfig.DEFAULT_SUPABASE_URL, parsed.jdbcUrl);
        assertEquals(DataSourceConfig.DEFAULT_SUPABASE_USER, parsed.username);
    }

    @Test
    void testResolveValidUrl_ReplacesLocalhostInRenderContainer() {
        MockEnvironment env = new MockEnvironment();
        env.setProperty("RENDER", "true");
        DataSourceConfig config = new DataSourceConfig(env);

        DataSourceConfig.ParsedDbConfig parsed = config.resolveDbConfig(
                "jdbc:postgresql://localhost:5432/cajaya_test",
                "cajaya_test",
                "secret"
        );

        // En Render / contenedor en la nube, localhost se reemplaza automáticamente por Supabase Pooler oficial
        assertEquals(DataSourceConfig.DEFAULT_SUPABASE_URL, parsed.jdbcUrl);
    }

    @Test
    void testResolveValidUrl_PreservesLocalhostInCiOrLocal() {
        MockEnvironment env = new MockEnvironment();
        env.setProperty("CI", "true");
        DataSourceConfig config = new DataSourceConfig(env);

        DataSourceConfig.ParsedDbConfig parsed = config.resolveDbConfig(
                "jdbc:postgresql://127.0.0.1:5432/cajaya_test",
                "cajaya_test",
                "secret"
        );

        // En CI o entorno local, localhost se preserva para pruebas unitarias de PostgreSQL
        assertEquals("jdbc:postgresql://127.0.0.1:5432/cajaya_test", parsed.jdbcUrl);
    }

    @Test
    void testResolveValidUrl_ParsesPostgresUriFormat() {
        MockEnvironment env = new MockEnvironment();
        DataSourceConfig config = new DataSourceConfig(env);

        DataSourceConfig.ParsedDbConfig parsed = config.resolveDbConfig(
                "postgres://user123:pass456@db.render.internal:5432/mydb",
                null,
                null
        );

        assertTrue(parsed.jdbcUrl.startsWith("jdbc:postgresql://db.render.internal:5432/mydb"));
        assertEquals("user123", parsed.username);
        assertEquals("pass456", parsed.password);
    }

    @Test
    void testResolveValidUrl_HandlesJdbcPrefixAndNormalParams() {
        MockEnvironment env = new MockEnvironment();
        DataSourceConfig config = new DataSourceConfig(env);

        DataSourceConfig.ParsedDbConfig parsed = config.resolveDbConfig(
                "jdbc:postgresql://remote.db.com:5432/prod_db",
                "myuser",
                "mypass"
        );

        assertEquals("jdbc:postgresql://remote.db.com:5432/prod_db", parsed.jdbcUrl);
        assertEquals("myuser", parsed.username);
        assertEquals("mypass", parsed.password);
    }
}
