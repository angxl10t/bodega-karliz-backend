package com.bodega.backend.config;

import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class DollarQuotedSqlSplitterTest {

    @Test
    void mantieneIntactosBloquesDoYFuncionesConDollarQuoting() {
        String sql = """
                -- Comentario inicial con punto y coma ; que no debe dividir
                DO $$
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM bodegas) THEN
                        INSERT INTO bodegas(nombre) VALUES ('Bodega ; Demo');
                    END IF;
                END $$;

                CREATE OR REPLACE FUNCTION app_current_tenant_id() RETURNS BIGINT AS $$
                DECLARE
                    v_id BIGINT;
                BEGIN
                    v_id := NULLIF(current_setting('app.current_tenant_id', true), '')::BIGINT;
                    RETURN v_id;
                EXCEPTION WHEN OTHERS THEN
                    RETURN NULL;
                END;
                $$ LANGUAGE plpgsql STABLE;

                CREATE INDEX IF NOT EXISTS idx_demo ON productos(id_bodega);
                /* Comentario con /* anidamiento ; */ y punto y coma ; */
                """;

        List<String> statements = DollarQuotedSqlSplitter.splitStatements(sql);
        assertEquals(3, statements.size());
        assertTrue(statements.get(0).contains("DO $$"));
        assertTrue(statements.get(0).contains("VALUES ('Bodega ; Demo');"));
        assertTrue(statements.get(0).endsWith("END $$"));

        assertTrue(statements.get(1).startsWith("CREATE OR REPLACE FUNCTION app_current_tenant_id()"));
        assertTrue(statements.get(1).contains("RETURN v_id;"));
        assertTrue(statements.get(1).endsWith("$$ LANGUAGE plpgsql STABLE"));

        assertEquals("CREATE INDEX IF NOT EXISTS idx_demo ON productos(id_bodega)", statements.get(2));
    }

    @Test
    void soportaTagsPersonalizadosYParametrosPosicionales() {
        String sql = """
                DO $mig$
                BEGIN
                    EXECUTE 'SELECT $1' USING 42;
                END $mig$;
                SELECT $1 AS param_ok;
                """;

        List<String> statements = DollarQuotedSqlSplitter.splitStatements(sql);
        assertEquals(2, statements.size());
        assertTrue(statements.get(0).startsWith("DO $mig$"));
        assertTrue(statements.get(0).endsWith("END $mig$"));
        assertEquals("SELECT $1 AS param_ok", statements.get(1));
    }

    @Test
    void divideCorrectamenteMigracionesRealesV2yV14SinFragmentarPlPgSql() throws IOException {
        String v2 = loadClasspathSql("db/migration/v2_rls_and_refinement.sql");
        List<String> v2Statements = DollarQuotedSqlSplitter.splitStatements(v2);

        assertTrue(v2Statements.stream().anyMatch(s ->
                s.contains("CREATE OR REPLACE FUNCTION app_current_tenant_id()")
                        && s.contains("$$ LANGUAGE plpgsql STABLE")),
                "La función app_current_tenant_id() no debe fragmentarse por puntos y coma internos");
        assertTrue(v2Statements.stream().anyMatch(s ->
                s.contains("CREATE OR REPLACE FUNCTION app_is_superadmin()")
                        && s.contains("$$ LANGUAGE plpgsql STABLE")),
                "La función app_is_superadmin() no debe fragmentarse por puntos y coma internos");

        String v14 = loadClasspathSql("db/migration/v14_enable_rls_all_tables.sql");
        List<String> v14Statements = DollarQuotedSqlSplitter.splitStatements(v14);
        long doBlockCount = v14Statements.stream()
                .filter(s -> s.contains("DO $$") && s.contains("END $$"))
                .count();
        assertTrue(doBlockCount >= 9, "Todos los bloques DO $$ ... END $$ de v14 deben quedar intactos");
    }

    private static String loadClasspathSql(String path) throws IOException {
        ClassPathResource resource = new ClassPathResource(path);
        return new String(resource.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
    }
}
