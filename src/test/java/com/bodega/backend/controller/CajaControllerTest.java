package com.bodega.backend.controller;

import com.bodega.backend.dto.CierreCajaDTO;
import com.bodega.backend.dto.EgresoCajaDTO;
import com.bodega.backend.dto.FondoCajaDTO;
import com.bodega.backend.service.CajaService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class CajaControllerTest {

    @Mock
    private CajaService cajaService;

    @InjectMocks
    private CajaController cajaController;

    private EgresoCajaDTO egresoDTO;
    private FondoCajaDTO fondoDTO;

    @BeforeEach
    void setUp() {
        egresoDTO = new EgresoCajaDTO();
        egresoDTO.setIdEgreso(1L);
        egresoDTO.setMonto(new BigDecimal("12.00"));
        egresoDTO.setMotivo("Bolsas plásticas");

        fondoDTO = new FondoCajaDTO();
        fondoDTO.setIdFondoCaja(1L);
        fondoDTO.setMontoInicial(new BigDecimal("50.00"));
        fondoDTO.setFecha(LocalDate.now());
    }

    @Test
    void testRegistrarEgreso() {
        when(cajaService.registrarEgreso(any(EgresoCajaDTO.class))).thenReturn(egresoDTO);

        ResponseEntity<EgresoCajaDTO> res = cajaController.registrarEgreso(egresoDTO);
        assertNotNull(res);
        assertEquals(HttpStatus.CREATED, res.getStatusCode());
        assertEquals(new BigDecimal("12.00"), res.getBody().getMonto());
    }

    @Test
    void testListarEgresos() {
        when(cajaService.listarEgresos(any())).thenReturn(List.of(egresoDTO));

        ResponseEntity<List<EgresoCajaDTO>> res = cajaController.listarEgresos(LocalDate.now());
        assertNotNull(res);
        assertEquals(HttpStatus.OK, res.getStatusCode());
        assertEquals(1, res.getBody().size());
    }

    @Test
    void testAnularEgreso() {
        doNothing().when(cajaService).anularEgreso(1L, "Motivo");

        ResponseEntity<Void> res = cajaController.anularEgreso(1L, "Motivo");
        assertNotNull(res);
        assertEquals(HttpStatus.NO_CONTENT, res.getStatusCode());
        verify(cajaService).anularEgreso(1L, "Motivo");
    }

    @Test
    void testRegistrarFondoInicial() {
        when(cajaService.registrarFondoInicial(any(FondoCajaDTO.class))).thenReturn(fondoDTO);

        ResponseEntity<FondoCajaDTO> res = cajaController.registrarFondoInicial(fondoDTO);
        assertNotNull(res);
        assertEquals(HttpStatus.OK, res.getStatusCode());
        assertEquals(new BigDecimal("50.00"), res.getBody().getMontoInicial());
    }

    @Test
    void testObtenerArqueoCompleto() {
        CierreCajaDTO arqueo = new CierreCajaDTO();
        arqueo.setTotalVentas(new BigDecimal("150.00"));
        arqueo.setFondoInicial(new BigDecimal("50.00"));
        arqueo.setTotalEgresos(new BigDecimal("10.00"));
        arqueo.setTotalEfectivoEsperado(new BigDecimal("190.00"));

        when(cajaService.obtenerArqueoCompleto(any())).thenReturn(arqueo);

        ResponseEntity<CierreCajaDTO> res = cajaController.obtenerArqueoCompleto(LocalDate.now());
        assertNotNull(res);
        assertEquals(HttpStatus.OK, res.getStatusCode());
        assertEquals(new BigDecimal("190.00"), res.getBody().getTotalEfectivoEsperado());
    }
}
