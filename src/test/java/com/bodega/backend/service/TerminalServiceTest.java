package com.bodega.backend.service;

import com.bodega.backend.dto.SolicitudCodigoVinculacionResponseDTO;
import com.bodega.backend.dto.TerminalResponseDTO;
import com.bodega.backend.dto.VincularTerminalRequestDTO;
import com.bodega.backend.dto.VincularTerminalResponseDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.TerminalPOS;
import com.bodega.backend.entity.TerminalPairingCode;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.TerminalPairingCodeRepository;
import com.bodega.backend.repository.TerminalRepository;
import com.bodega.backend.repository.UsuarioRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.OffsetDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class TerminalServiceTest {

    @Mock
    private TerminalRepository terminalRepository;

    @Mock
    private TerminalPairingCodeRepository pairingCodeRepository;

    @Mock
    private BodegaRepository bodegaRepository;

    @Mock
    private UsuarioRepository usuarioRepository;

    @InjectMocks
    private TerminalService terminalService;

    private Bodega bodegaTest;

    @BeforeEach
    void setUp() {
        bodegaTest = new Bodega();
        bodegaTest.setIdBodega(1L);
        bodegaTest.setNombreComercial("Bodega Central");
        bodegaTest.setEstado(true);
    }

    @Test
    void testGenerarCodigoVinculacion_Exitoso() {
        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodegaTest));
        when(pairingCodeRepository.findByBodega_IdBodegaAndUsadoFalseAndFechaExpiracionAfter(eq(1L), any(OffsetDateTime.class)))
                .thenReturn(Collections.emptyList());
        when(pairingCodeRepository.save(any(TerminalPairingCode.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        SolicitudCodigoVinculacionResponseDTO res = terminalService.generarCodigoVinculacion(1L, "admin_user");

        assertNotNull(res);
        assertNotNull(res.getCodigo());
        assertEquals(6, res.getCodigo().length());
        assertTrue(res.getCodigo().matches("^[0-9]{6}$"));
        assertEquals(600, res.getExpiraEnSegundos());
        assertEquals(1L, res.getIdBodega());
        assertEquals("Bodega Central", res.getNombreBodega());
        verify(pairingCodeRepository, times(1)).save(any(TerminalPairingCode.class));
    }

    @Test
    void testVincularTerminal_Exitoso() {
        TerminalPairingCode pairing = new TerminalPairingCode();
        pairing.setId(10L);
        pairing.setBodega(bodegaTest);
        pairing.setCodigo("123456");
        pairing.setFechaExpiracion(OffsetDateTime.now().plusMinutes(5));
        pairing.setUsado(false);

        when(pairingCodeRepository.findByCodigoAndUsadoFalse("123456"))
                .thenReturn(Optional.of(pairing));
        when(terminalRepository.countByBodega_IdBodegaAndEstadoTrue(1L)).thenReturn(0L);
        when(terminalRepository.save(any(TerminalPOS.class))).thenAnswer(inv -> {
            TerminalPOS t = inv.getArgument(0);
            t.setIdTerminal(99L);
            return t;
        });

        VincularTerminalRequestDTO req = new VincularTerminalRequestDTO();
        req.setCodigoEmparejamiento("123456");
        req.setNombreTerminal("Caja Principal");
        req.setDeviceModel("POS Sunmi");

        VincularTerminalResponseDTO res = terminalService.vincularTerminal(req, "192.168.1.1");

        assertNotNull(res);
        assertNotNull(res.getTerminalToken());
        assertTrue(res.getTerminalToken().startsWith("term_"));
        assertEquals(1L, res.getIdBodega());
        assertEquals(99L, res.getIdTerminal());
        assertEquals("Caja Principal", res.getNombreTerminal());
        assertTrue(pairing.getUsado());
        verify(pairingCodeRepository).save(pairing);
    }

    @Test
    void testVincularTerminal_CodigoInvalido() {
        when(pairingCodeRepository.findByCodigoAndUsadoFalse("999999"))
                .thenReturn(Optional.empty());

        VincularTerminalRequestDTO req = new VincularTerminalRequestDTO();
        req.setCodigoEmparejamiento("999999");

        assertThrows(IllegalArgumentException.class, () ->
                terminalService.vincularTerminal(req, "127.0.0.1"));
    }

    @Test
    void testVincularTerminal_CodigoExpirado() {
        TerminalPairingCode pairing = new TerminalPairingCode();
        pairing.setId(10L);
        pairing.setBodega(bodegaTest);
        pairing.setCodigo("123456");
        pairing.setFechaExpiracion(OffsetDateTime.now().minusMinutes(1)); // Expirado
        pairing.setUsado(false);

        when(pairingCodeRepository.findByCodigoAndUsadoFalse("123456"))
                .thenReturn(Optional.of(pairing));

        VincularTerminalRequestDTO req = new VincularTerminalRequestDTO();
        req.setCodigoEmparejamiento("123456");

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                terminalService.vincularTerminal(req, "127.0.0.1"));
        assertTrue(ex.getMessage().contains("expirado"));
        assertTrue(pairing.getUsado());
    }

    @Test
    void testValidarTerminalToken_Exitoso() {
        TerminalPOS term = new TerminalPOS();
        term.setIdTerminal(5L);
        term.setBodega(bodegaTest);
        term.setTerminalToken("term_token_abc_123");
        term.setEstado(true);

        when(terminalRepository.findByTerminalTokenAndEstadoTrue("term_token_abc_123"))
                .thenReturn(Optional.of(term));

        TerminalPOS resultado = terminalService.validarTerminalToken("term_token_abc_123");
        assertNotNull(resultado);
        assertEquals(5L, resultado.getIdTerminal());
        verify(terminalRepository).save(term);
    }

    @Test
    void testRevocarTerminal_Exitoso() {
        TerminalPOS term = new TerminalPOS();
        term.setIdTerminal(7L);
        term.setBodega(bodegaTest);
        term.setEstado(true);

        when(terminalRepository.findById(7L)).thenReturn(Optional.of(term));

        terminalService.revocarTerminal(1L, 7L);

        assertFalse(term.getEstado());
        verify(terminalRepository).save(term);
    }
}
