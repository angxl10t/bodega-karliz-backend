package com.bodega.backend.service;

import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Proveedor;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.ProveedorRepository;
import com.bodega.backend.repository.StarterPackPresetRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class StarterPackServiceTest {

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

    @Mock
    private ProveedorRepository proveedorRepository;

    private StarterPackService starterPackService;

    @BeforeEach
    void setUp() {
        starterPackService = new StarterPackService(
                jdbcTemplate,
                bodegaRepository,
                categoriaRepository,
                productoRepository,
                starterPackPresetRepository,
                proveedorRepository
        );
    }

    @Test
    @DisplayName("Debe contener los 25 distribuidores y fabricantes oficiales canónicos del Perú")
    void testProveedoresCanonicosContiene25ProveedoresReales() {
        assertEquals(25, StarterPackService.PROVEEDORES_CANONICOS.length);

        Set<String> rucs = new HashSet<>();
        for (String[] prov : StarterPackService.PROVEEDORES_CANONICOS) {
            assertEquals(4, prov.length);
            String ruc = prov[0];
            String razonSocial = prov[1];
            String direccion = prov[2];
            String telefono = prov[3];

            assertTrue(ruc.matches("20\\d{9}"), "El RUC debe tener 11 dígitos y empezar con 20: " + ruc);
            assertFalse(razonSocial.isBlank(), "La razón social no debe estar vacía");
            assertFalse(direccion.isBlank(), "La dirección no debe estar vacía");
            assertFalse(telefono.isBlank(), "El teléfono no debe estar vacío");
            rucs.add(ruc);
        }
        assertEquals(25, rucs.size(), "Todos los 25 RUCs deben ser únicos");
    }

    @Test
    @DisplayName("El 100% de los productos del catálogo de 407 ítems debe resolver a un RUC oficial válido")
    void testTodosLosProductosResuelvenAProveedorOficialValido() {
        Set<String> rucsOficiales = new HashSet<>();
        for (String[] prov : StarterPackService.PROVEEDORES_CANONICOS) {
            rucsOficiales.add(prov[0]);
        }

        Map<String, Integer> conteoPorRuc = new HashMap<>();
        for (String[] prod : StarterPackService.PRODUCTOS_STARTER_PACK) {
            String ean = prod[0];
            String nombre = prod[1];
            String marca = prod[2];
            String categoria = prod[3];

            String rucResuelto = StarterPackService.resolverRucProveedor(marca, nombre, categoria);
            assertNotNull(rucResuelto, "El RUC no puede ser nulo para " + nombre);
            assertTrue(rucsOficiales.contains(rucResuelto),
                    "El RUC resuelto '" + rucResuelto + "' para producto '" + nombre + "' debe pertenecer a los 25 oficiales");

            conteoPorRuc.merge(rucResuelto, 1, Integer::sum);
        }

        // Verificar que los principales distribuidores tengan catálogo asignado
        assertTrue(conteoPorRuc.getOrDefault(StarterPackService.RUC_ARCA_CONTINENTAL, 0) > 0, "Arca Continental debe tener productos");
        assertTrue(conteoPorRuc.getOrDefault(StarterPackService.RUC_BACKUS, 0) > 0, "Backus debe tener productos");
        assertTrue(conteoPorRuc.getOrDefault(StarterPackService.RUC_ALICORP, 0) > 0, "Alicorp debe tener productos");
        assertTrue(conteoPorRuc.getOrDefault(StarterPackService.RUC_GLORIA, 0) > 0, "Gloria debe tener productos");
        assertTrue(conteoPorRuc.getOrDefault(StarterPackService.RUC_NESTLE, 0) > 0, "Nestlé debe tener productos");
        assertTrue(conteoPorRuc.getOrDefault(StarterPackService.RUC_PEPSICO, 0) > 0, "Pepsico debe tener productos");
    }

    @Test
    @DisplayName("asegurarProveedoresCanonicos desactiva mayoristas falsos y registra proveedores canónicos")
    void testAsegurarProveedoresCanonicos() {
        Bodega bodega = new Bodega();
        bodega.setIdBodega(1L);
        bodega.setNombreComercial("Bodega Karliz");

        when(proveedorRepository.findByBodega_IdBodegaAndRuc(eq(1L), anyString())).thenReturn(Optional.empty());
        when(proveedorRepository.save(any(Proveedor.class))).thenAnswer(invocation -> {
            Proveedor p = invocation.getArgument(0);
            p.setIdProveedor(100L);
            return p;
        });

        Map<String, Proveedor> resultado = starterPackService.asegurarProveedoresCanonicos(bodega);

        assertEquals(25, resultado.size());
        verify(jdbcTemplate, times(1)).update(contains("UPDATE proveedores SET estado = false"), eq(1L));
        verify(proveedorRepository, times(25)).save(any(Proveedor.class));
    }
}
