package com.bodega.backend.service;

import com.bodega.backend.dto.StarterPackPresetDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Categoria;
import com.bodega.backend.entity.StarterPackPreset;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.StarterPackPresetRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;

import java.math.BigDecimal;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class StarterPackPresetServiceTest {

    @Mock
    private JdbcTemplate jdbcTemplate;

    @Mock
    private BodegaRepository bodegaRepository;

    @Mock
    private CategoriaRepository categoriaRepository;

    @Mock
    private ProductoRepository productoRepository;

    @Mock
    private StarterPackPresetRepository starterPackPresetRepository;

    private StarterPackService starterPackService;

    @BeforeEach
    void setUp() {
        starterPackService = new StarterPackService(
                jdbcTemplate,
                bodegaRepository,
                categoriaRepository,
                productoRepository,
                starterPackPresetRepository
        );
    }

    @Test
    void testInicializarPresetGlobalSiVacio_whenEmpty_seedsCatalog() {
        when(starterPackPresetRepository.count()).thenReturn(0L);

        starterPackService.inicializarPresetGlobalSiVacio();

        verify(starterPackPresetRepository, times(1)).saveAll(any());
    }

    @Test
    void testInicializarPresetGlobalSiVacio_whenAlreadyHasData_doesNotReseed() {
        when(starterPackPresetRepository.count()).thenReturn(100L);

        starterPackService.inicializarPresetGlobalSiVacio();

        verify(starterPackPresetRepository, never()).saveAll(any());
    }

    @Test
    void testListarPresetGlobal_returnsDTOList() {
        StarterPackPreset p1 = StarterPackPreset.builder()
                .idPreset(1L)
                .codigoBarras("7750106001010")
                .nombre("Inca Kola 500ml")
                .categoria("Gaseosas y Bebidas")
                .precioVenta(new BigDecimal("3.00"))
                .precioCosto(new BigDecimal("2.30"))
                .activo(true)
                .build();

        when(starterPackPresetRepository.count()).thenReturn(1L);
        when(starterPackPresetRepository.findAllByOrderByIdPresetAsc()).thenReturn(List.of(p1));

        List<StarterPackPresetDTO> result = starterPackService.listarPresetGlobal();

        assertNotNull(result);
        assertEquals(1, result.size());
        assertEquals("7750106001010", result.get(0).getCodigoBarras());
        assertEquals("Inca Kola 500ml", result.get(0).getNombre());
    }

    @Test
    void testCrearPresetItem_success() {
        StarterPackPresetDTO dto = StarterPackPresetDTO.builder()
                .codigoBarras("7751234567899")
                .nombre("Cerveza Cusqueña Trigo")
                .marca("Cusqueña")
                .categoria("Bebidas Alcohólicas")
                .precioVenta(new BigDecimal("6.50"))
                .precioCosto(new BigDecimal("5.00"))
                .imagenUrl("packshots/cerveza_cusquena.png")
                .activo(true)
                .build();

        when(starterPackPresetRepository.existsByCodigoBarras("7751234567899")).thenReturn(false);
        when(starterPackPresetRepository.save(any(StarterPackPreset.class))).thenAnswer(inv -> {
            StarterPackPreset p = inv.getArgument(0);
            p.setIdPreset(99L);
            return p;
        });

        StarterPackPresetDTO creado = starterPackService.crearPresetItem(dto);

        assertNotNull(creado);
        assertEquals(99L, creado.getIdPreset());
        assertEquals("7751234567899", creado.getCodigoBarras());
        assertEquals("Cerveza Cusqueña Trigo", creado.getNombre());
        verify(starterPackPresetRepository, times(1)).save(any(StarterPackPreset.class));
    }

    @Test
    void testCrearPresetItem_duplicateBarcode_throwsException() {
        StarterPackPresetDTO dto = StarterPackPresetDTO.builder()
                .codigoBarras("7751234567899")
                .nombre("Cerveza Cusqueña Trigo")
                .categoria("Bebidas Alcohólicas")
                .precioVenta(new BigDecimal("6.50"))
                .build();

        when(starterPackPresetRepository.existsByCodigoBarras("7751234567899")).thenReturn(true);

        assertThrows(IllegalArgumentException.class, () -> starterPackService.crearPresetItem(dto));
        verify(starterPackPresetRepository, never()).save(any());
    }

    @Test
    void testActualizarPresetItem_success() {
        StarterPackPreset existente = StarterPackPreset.builder()
                .idPreset(10L)
                .codigoBarras("7750000000001")
                .nombre("Arroz Costeño 1kg")
                .categoria("Abarrotes y Despensa")
                .precioVenta(new BigDecimal("4.80"))
                .precioCosto(new BigDecimal("3.80"))
                .activo(true)
                .build();

        when(starterPackPresetRepository.findById(10L)).thenReturn(Optional.of(existente));
        when(starterPackPresetRepository.save(any(StarterPackPreset.class))).thenAnswer(inv -> inv.getArgument(0));

        StarterPackPresetDTO modificado = StarterPackPresetDTO.builder()
                .nombre("Arroz Costeño Extra 1kg")
                .precioVenta(new BigDecimal("5.20"))
                .precioCosto(new BigDecimal("4.10"))
                .build();

        StarterPackPresetDTO result = starterPackService.actualizarPresetItem(10L, modificado);

        assertNotNull(result);
        assertEquals("Arroz Costeño Extra 1kg", result.getNombre());
        assertEquals(new BigDecimal("5.20"), result.getPrecioVenta());
        assertEquals(new BigDecimal("4.10"), result.getPrecioCosto());
    }

    @Test
    void testEliminarPresetItem_success() {
        when(starterPackPresetRepository.existsById(5L)).thenReturn(true);

        starterPackService.eliminarPresetItem(5L);

        verify(starterPackPresetRepository, times(1)).deleteById(5L);
    }

    @Test
    void testRestablecerPresetGlobal_deletesAndReseeds() {
        when(starterPackPresetRepository.count()).thenReturn(0L);
        when(starterPackPresetRepository.findAllByOrderByIdPresetAsc()).thenReturn(List.of());

        List<StarterPackPresetDTO> resultado = starterPackService.restablecerPresetGlobal();

        verify(starterPackPresetRepository, times(1)).deleteAll();
        verify(starterPackPresetRepository, times(1)).saveAll(any());
        assertNotNull(resultado);
    }
}
