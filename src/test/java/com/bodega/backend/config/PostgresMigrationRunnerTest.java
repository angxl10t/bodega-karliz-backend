package com.bodega.backend.config;

import org.junit.jupiter.api.Test;
import org.springframework.core.io.DefaultResourceLoader;

import javax.sql.DataSource;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Properties;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.mock;

class PostgresMigrationRunnerTest {

    @Test
    void todosLosScriptsConfiguradosExistenYSeParseanSinFaltantes() throws IOException {
        DefaultResourceLoader loader = new DefaultResourceLoader();

        PostgresMigrationRunner defaultRunner = new PostgresMigrationRunner(
                mock(DataSource.class), loader, true, true, "");
        assertEquals(24, defaultRunner.getLocations().size(),
                "DEFAULT_MIGRATION_LOCATIONS debe incluir las 24 migraciones activas.");

        for (String loc : defaultRunner.getLocations()) {
            var res = loader.getResource(loc);
            assertTrue(res.exists(), "Debe existir el recurso de migración: " + loc);
            String sql = new String(res.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
            assertFalse(DollarQuotedSqlSplitter.splitStatements(sql).isEmpty(),
                    "El script " + loc + " debe producir al menos una sentencia SQL.");
        }

        Path mainPropsPath = Path.of("src/main/resources/application.properties");
        assertTrue(Files.exists(mainPropsPath));
        Properties props = new Properties();
        try (var in = Files.newInputStream(mainPropsPath)) {
            props.load(in);
        }

        String rawLocations = props.getProperty("cajaya.migrations.locations");
        assertNotNull(rawLocations);
        List<String> configuredLocations = PostgresMigrationRunner.parseLocations(rawLocations);
        assertEquals(PostgresMigrationRunner.DEFAULT_MIGRATION_LOCATIONS, configuredLocations,
                "cajaya.migrations.locations en application.properties debe coincidir exactamente con DEFAULT_MIGRATION_LOCATIONS.");
    }
}
