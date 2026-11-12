package com.bodega.backend;

import com.bodega.backend.integration.AbstractPostgresIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationContext;

import static org.junit.jupiter.api.Assertions.assertNotNull;

class BodegaBackendApplicationTests extends AbstractPostgresIntegrationTest {

    @Autowired
    private ApplicationContext applicationContext;

    @Test
    void contextLoadsAgainstRealPostgreSQL() {
        assertNotNull(applicationContext);
    }
}
