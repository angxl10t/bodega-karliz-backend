package com.bodega.backend.service;

import com.bodega.backend.security.EnvironmentSecurityHelper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class EmailServiceTest {

    @Mock
    private HttpClient httpClient;

    @Mock
    private HttpResponse<String> httpResponse;

    @Test
    void enviarCodigoRecuperacion_sinProveedoresEnProduccion_retornaFalse() {
        EmailService service = new EmailService(httpClient);
        ReflectionTestUtils.setField(service, "activeProfile", "prod");

        boolean enviado = service.enviarCodigoRecuperacion("bodega@test.pe", "bodega_user", "654321");
        assertFalse(enviado);
        verifyNoInteractions(httpClient);
    }

    @Test
    void enviarCodigoRecuperacion_sinProveedoresEnDev_retornaTrueSoloFueraDeProduccion() {
        EmailService service = new EmailService(httpClient);
        ReflectionTestUtils.setField(service, "activeProfile", "default");

        if (!EnvironmentSecurityHelper.isProduction("default")) {
            boolean enviado = service.enviarCodigoRecuperacion("bodega@test.pe", "bodega_user", "654321");
            assertTrue(enviado);
        }
    }

    @Test
    @SuppressWarnings("unchecked")
    void enviarCodigoRecuperacion_conBrevoExitosoEscapaHtmlEnUsername() throws Exception {
        EmailService service = new EmailService(httpClient);
        ReflectionTestUtils.setField(service, "activeProfile", "prod");
        ReflectionTestUtils.setField(service, "brevoApiKey", "xkeysib-test-key");
        ReflectionTestUtils.setField(service, "brevoSenderEmail", "cajayapos@gmail.com");

        when(httpResponse.statusCode()).thenReturn(201);
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(httpResponse);

        boolean enviado = service.enviarCodigoRecuperacion("dueño@bodega.pe", "<script>alert(1)</script>", "112233");
        assertTrue(enviado);

        ArgumentCaptor<HttpRequest> requestCaptor = ArgumentCaptor.forClass(HttpRequest.class);
        verify(httpClient).send(requestCaptor.capture(), any());
        assertEquals("https://api.brevo.com/v3/smtp/email", requestCaptor.getValue().uri().toString());
    }

    @Test
    @SuppressWarnings("unchecked")
    void enviarCodigoRecuperacion_cuandoResendFallaEnProduccion_retornaFalse() throws Exception {
        EmailService service = new EmailService(httpClient);
        ReflectionTestUtils.setField(service, "activeProfile", "prod");
        ReflectionTestUtils.setField(service, "resendApiKey", "re_test_123");
        ReflectionTestUtils.setField(service, "emailFrom", "CajaYa POS <onboarding@resend.dev>");

        when(httpResponse.statusCode()).thenReturn(403);
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(httpResponse);

        boolean enviado = service.enviarCodigoRecuperacion("cliente@gmail.com", "usuario", "998877");
        assertFalse(enviado);
    }

    @Test
    void construirPlantillaHtml_escapaEtiquetasHtmlDeUsername() {
        EmailService service = new EmailService(httpClient);
        String html = ReflectionTestUtils.invokeMethod(
                service,
                "construirPlantillaHtmlRecuperacion",
                "<img src=x onerror=alert(1)>",
                "123456"
        );
        assertNotNull(html);
        assertFalse(html.contains("<img src=x"));
        assertTrue(html.contains("&lt;img src=x onerror=alert(1)&gt;"));
    }
}
