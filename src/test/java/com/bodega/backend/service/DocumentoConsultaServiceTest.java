package com.bodega.backend.service;

import com.bodega.backend.dto.DniConsultaDTO;
import com.bodega.backend.dto.RucConsultaDTO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

public class DocumentoConsultaServiceTest {

    private DocumentoConsultaService documentoService;

    @BeforeEach
    void setUp() {
        documentoService = new DocumentoConsultaService();
    }

    @Test
    void testValidarRucAlgoritmo_RucsValidos() {
        // RUC oficial de SUNAT
        assertTrue(DocumentoConsultaService.validarRucAlgoritmo("20100070970"));
        // RUC oficial de BCP
        assertTrue(DocumentoConsultaService.validarRucAlgoritmo("20131312955"));
    }

    @Test
    void testValidarRucAlgoritmo_RucsInvalidos() {
        // Dígito verificador incorrecto
        assertFalse(DocumentoConsultaService.validarRucAlgoritmo("20100070971"));
        // Prefijo no permitido
        assertFalse(DocumentoConsultaService.validarRucAlgoritmo("30100070970"));
        // Longitud menor a 11 dígitos
        assertFalse(DocumentoConsultaService.validarRucAlgoritmo("2010007097"));
        // Con letras o caracteres especiales
        assertFalse(DocumentoConsultaService.validarRucAlgoritmo("2010007097A"));
        // Nulo o vacío
        assertFalse(DocumentoConsultaService.validarRucAlgoritmo(null));
        assertFalse(DocumentoConsultaService.validarRucAlgoritmo(""));
    }

    @Test
    void testConsultarDni_FormatoInvalido_LanzaExcepcion() {
        assertThrows(RuntimeException.class, () -> documentoService.consultarDni("12345"));
        assertThrows(RuntimeException.class, () -> documentoService.consultarDni("ABCDEFGH"));
        assertThrows(RuntimeException.class, () -> documentoService.consultarDni(null));
    }

    @Test
    void testConsultarDni_FallbackOffline() {
        DniConsultaDTO resultado = documentoService.consultarDni("71234567");

        assertNotNull(resultado);
        assertEquals("71234567", resultado.getNumero());
        assertFalse(resultado.isEncontrado());
        assertEquals("FALLBACK_OFFLINE", resultado.getFuente());
    }

    @Test
    void testConsultarRuc_FormatoInvalido_LanzaExcepcion() {
        assertThrows(RuntimeException.class, () -> documentoService.consultarRuc("12345"));
        assertThrows(RuntimeException.class, () -> documentoService.consultarRuc("201000709701"));
        assertThrows(RuntimeException.class, () -> documentoService.consultarRuc(null));
    }

    @Test
    void testConsultarRuc_FallbackConAlgoritmoValido() {
        RucConsultaDTO resultado = documentoService.consultarRuc("20100070970");

        assertNotNull(resultado);
        assertEquals("20100070970", resultado.getNumero());
        assertTrue(resultado.isEsActivo());
        assertTrue(resultado.isEsHabido());
        assertEquals("VALIDACION_LOCAL_MODULO11", resultado.getFuente());
    }
}
