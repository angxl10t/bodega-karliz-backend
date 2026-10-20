package com.bodega.backend.service;

import com.bodega.backend.dto.CategoriaDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Categoria;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.ProductoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class CategoriaServiceTest {

    @Mock
    private CategoriaRepository categoriaRepository;

    @Mock
    private ProductoRepository productoRepository;

    @Mock
    private TenantService tenantService;

    @InjectMocks
    private CategoriaService categoriaService;

    private Bodega bodega;
    private Categoria categoria;

    @BeforeEach
    void setUp() {
        bodega = new Bodega();
        bodega.setIdBodega(1L);
        bodega.setNombreComercial("Bodega Central");

        categoria = new Categoria();
        categoria.setIdCategoria(10L);
        categoria.setNombre("Lácteos");
        categoria.setDescripcion("Leches, quesos y yogures");
        categoria.setEstado(true);
        categoria.setBodega(bodega);
    }

    @Test
    void testListarActivas() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(categoriaRepository.findByBodega_IdBodegaAndEstadoTrue(1L)).thenReturn(List.of(categoria));

        List<CategoriaDTO> resultado = categoriaService.listarActivas();

        assertNotNull(resultado);
        assertEquals(1, resultado.size());
        assertEquals("Lácteos", resultado.get(0).getNombre());
    }

    @Test
    void testCrearCategoria_Exito() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(tenantService.getCurrentBodega()).thenReturn(bodega);
        when(categoriaRepository.findByBodega_IdBodegaAndNombreIgnoreCase(1L, "Snacks"))
                .thenReturn(Optional.empty());

        Categoria guardada = new Categoria();
        guardada.setIdCategoria(20L);
        guardada.setNombre("Snacks");
        guardada.setBodega(bodega);
        guardada.setEstado(true);

        when(categoriaRepository.save(any(Categoria.class))).thenReturn(guardada);

        CategoriaDTO dto = new CategoriaDTO();
        dto.setNombre("Snacks");

        CategoriaDTO creada = categoriaService.crear(dto);

        assertNotNull(creada);
        assertEquals(20L, creada.getIdCategoria());
        assertEquals("Snacks", creada.getNombre());
        verify(categoriaRepository).save(any(Categoria.class));
    }

    @Test
    void testCrearCategoria_NombreVacio_LanzaExcepcion() {
        CategoriaDTO dto = new CategoriaDTO();
        dto.setNombre("   ");

        RuntimeException ex = assertThrows(RuntimeException.class, () -> categoriaService.crear(dto));
        assertTrue(ex.getMessage().contains("obligatorio"));
    }

    @Test
    void testCrearCategoria_DuplicadaActiva_LanzaExcepcion() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(categoriaRepository.findByBodega_IdBodegaAndNombreIgnoreCase(1L, "Lácteos"))
                .thenReturn(Optional.of(categoria));

        CategoriaDTO dto = new CategoriaDTO();
        dto.setNombre("Lácteos");

        RuntimeException ex = assertThrows(RuntimeException.class, () -> categoriaService.crear(dto));
        assertTrue(ex.getMessage().contains("Ya existe una categoría activa"));
    }

    @Test
    void testCrearCategoria_ReactivacionTransparente() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        Categoria inactiva = new Categoria();
        inactiva.setIdCategoria(15L);
        inactiva.setNombre("Golosinas");
        inactiva.setEstado(false);
        inactiva.setBodega(bodega);

        when(categoriaRepository.findByBodega_IdBodegaAndNombreIgnoreCase(1L, "Golosinas"))
                .thenReturn(Optional.of(inactiva));
        when(categoriaRepository.save(any(Categoria.class))).thenAnswer(invocation -> invocation.getArgument(0));

        CategoriaDTO dto = new CategoriaDTO();
        dto.setNombre("Golosinas");
        dto.setDescripcion("Chocolates y caramelos");

        CategoriaDTO reactivada = categoriaService.crear(dto);

        assertNotNull(reactivada);
        assertTrue(reactivada.getEstado());
        assertEquals("Chocolates y caramelos", reactivada.getDescripcion());
    }

    @Test
    void testActualizar_Exito() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(categoriaRepository.findByIdCategoriaAndBodega_IdBodega(10L, 1L))
                .thenReturn(Optional.of(categoria));
        when(categoriaRepository.existsByBodega_IdBodegaAndNombreIgnoreCaseAndIdCategoriaNot(1L, "Lácteos Frescos", 10L))
                .thenReturn(false);
        when(categoriaRepository.save(any(Categoria.class))).thenAnswer(invocation -> invocation.getArgument(0));

        CategoriaDTO dto = new CategoriaDTO();
        dto.setNombre("Lácteos Frescos");
        dto.setDescripcion("Nueva descripción");

        CategoriaDTO actualizada = categoriaService.actualizar(10L, dto);

        assertNotNull(actualizada);
        assertEquals("Lácteos Frescos", actualizada.getNombre());
        assertEquals("Nueva descripción", actualizada.getDescripcion());
    }

    @Test
    void testActualizar_Inactiva_LanzaExcepcion() {
        categoria.setEstado(false);
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(categoriaRepository.findByIdCategoriaAndBodega_IdBodega(10L, 1L))
                .thenReturn(Optional.of(categoria));

        CategoriaDTO dto = new CategoriaDTO();
        dto.setNombre("Nuevo Nombre");

        RuntimeException ex = assertThrows(RuntimeException.class, () -> categoriaService.actualizar(10L, dto));
        assertTrue(ex.getMessage().contains("No se puede editar una categoría inactiva"));
    }

    @Test
    void testDesactivar_ConProductosActivos_LanzaExcepcion() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(categoriaRepository.findByIdCategoriaAndBodega_IdBodega(10L, 1L))
                .thenReturn(Optional.of(categoria));
        when(productoRepository.existsByCategoria_IdCategoriaAndBodega_IdBodegaAndEstadoTrue(10L, 1L))
                .thenReturn(true);

        RuntimeException ex = assertThrows(RuntimeException.class, () -> categoriaService.desactivar(10L));
        assertTrue(ex.getMessage().contains("tiene productos activos asociados"));
        verify(categoriaRepository, never()).save(any(Categoria.class));
    }

    @Test
    void testDesactivar_SinProductosActivos_Exito() {
        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(categoriaRepository.findByIdCategoriaAndBodega_IdBodega(10L, 1L))
                .thenReturn(Optional.of(categoria));
        when(productoRepository.existsByCategoria_IdCategoriaAndBodega_IdBodegaAndEstadoTrue(10L, 1L))
                .thenReturn(false);

        categoriaService.desactivar(10L);

        assertFalse(categoria.getEstado());
        verify(categoriaRepository).save(categoria);
    }
}
