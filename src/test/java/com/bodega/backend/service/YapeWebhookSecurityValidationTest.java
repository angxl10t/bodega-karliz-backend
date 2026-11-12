package com.bodega.backend.service;

import com.bodega.backend.repository.YapeTransaccionRecibidaRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(MockitoExtension.class)
public class YapeWebhookSecurityValidationTest {

    @Mock
    private YapeTransaccionRecibidaRepository repository;

    @Test
    void validateSecret_rechazaSecretoDefaultEnProduccion() {
        YapeWebhookService service = new YapeWebhookService(repository);
        ReflectionTestUtils.setField(service, "configuredSecret", YapeWebhookService.DEFAULT_DEV_SECRET);
        ReflectionTestUtils.setField(service, "activeProfile", "prod");

        IllegalStateException ex = assertThrows(IllegalStateException.class, service::validateSecret);
        assertTrue(ex.getMessage().contains("YAPE_WEBHOOK_SECRET"));
    }

    @Test
    void validateSecret_rechazaSecretoCortoOMalConfigurado() {
        YapeWebhookService service = new YapeWebhookService(repository);
        ReflectionTestUtils.setField(service, "configuredSecret", "muyCorto");
        ReflectionTestUtils.setField(service, "activeProfile", "default");

        IllegalStateException ex = assertThrows(IllegalStateException.class, service::validateSecret);
        assertTrue(ex.getMessage().contains("16 caracteres"));
    }

    @Test
    void validateSecret_aceptaSecretoUnicoRobustoEnProduccion() {
        YapeWebhookService service = new YapeWebhookService(repository);
        ReflectionTestUtils.setField(service, "configuredSecret", "YapeProdSecret_998877665544_CajaYa");
        ReflectionTestUtils.setField(service, "activeProfile", "production");

        assertDoesNotThrow(service::validateSecret);
    }

    @Test
    void procesarNotificacionYape_rechazaHeaderVacio() {
        YapeWebhookService service = new YapeWebhookService(repository);
        ReflectionTestUtils.setField(service, "configuredSecret", "YapeProdSecret_998877665544_CajaYa");

        assertThrows(AccessDeniedException.class, () ->
                service.procesarNotificacionYape("   ", null));
    }
}
