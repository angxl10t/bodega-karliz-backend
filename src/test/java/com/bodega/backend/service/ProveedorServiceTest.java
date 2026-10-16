package com.bodega.backend.service;

import com.bodega.backend.dto.ProveedorDTO;
import com.bodega.backend.entity.Proveedor;
import com.bodega.backend.repository.ProveedorRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class ProveedorServiceTest {

    @Mock
    private ProveedorRepository proveedorRepository;

    @Mock
    private TenantService tenantService;

    @InjectMocks
    private ProveedorService proveedorService;

    @Test
    void testCrearProveedor_RucValido11Digitos_Exito() {
        ProveedorDTO dto = new ProveedorDTO();
        dto.setRuc("20601234567");
        dto.setRazonSocial("Distribuidora Gloria S.A.");
        dto.setDireccion("Av. República de Panamá 2461");
        dto.setTelefono("987654321");

        Proveedor mockGuardado = new Proveedor();
        mockGuardado.setIdProveedor(1L);
        mockGuardado.setRuc("20601234567");
        mockGuardado.setRazonSocial("Distribuidora Gloria S.A.");
        mockGuardado.setEstado(true);

        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(proveedorRepository.findByBodega_IdBodegaAndRuc(1L, "20601234567")).thenReturn(Optional.empty());
        when(proveedorRepository.save(any(Proveedor.class))).thenReturn(mockGuardado);

        ProveedorDTO resultado = proveedorService.crear(dto);

        assertNotNull(resultado);
        assertEquals("20601234567", resultado.getRuc());
        assertEquals("Distribuidora Gloria S.A.", resultado.getRazonSocial());
        verify(proveedorRepository, times(1)).save(any(Proveedor.class));
    }

    @Test
    void testCrearProveedor_DniValido8Digitos_Exito() {
        ProveedorDTO dto = new ProveedorDTO();
        dto.setRuc("45678901");
        dto.setRazonSocial("Juan Perez Distribuidor");

        Proveedor mockGuardado = new Proveedor();
        mockGuardado.setIdProveedor(2L);
        mockGuardado.setRuc("45678901");
        mockGuardado.setRazonSocial("Juan Perez Distribuidor");
        mockGuardado.setEstado(true);

        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(proveedorRepository.findByBodega_IdBodegaAndRuc(1L, "45678901")).thenReturn(Optional.empty());
        when(proveedorRepository.save(any(Proveedor.class))).thenReturn(mockGuardado);

        ProveedorDTO resultado = proveedorService.crear(dto);

        assertNotNull(resultado);
        assertEquals("45678901", resultado.getRuc());
    }

    @Test
    void testCrearProveedor_DocumentoInvalido_LanzaExcepcion() {
        ProveedorDTO dto = new ProveedorDTO();
        dto.setRuc("2060ABCDEF");
        dto.setRazonSocial("Empresa Invalida");

        RuntimeException ex = assertThrows(RuntimeException.class, () -> proveedorService.crear(dto));
        assertTrue(ex.getMessage().contains("DNI de 8 dígitos o RUC de 11 dígitos"));
        verify(proveedorRepository, never()).save(any(Proveedor.class));
    }

    @Test
    void testCrearProveedor_RucDuplicadoActivo_LanzaExcepcion() {
        ProveedorDTO dto = new ProveedorDTO();
        dto.setRuc("20601234567");
        dto.setRazonSocial("Otra Empresa");

        Proveedor existente = new Proveedor();
        existente.setIdProveedor(10L);
        existente.setRuc("20601234567");
        existente.setEstado(true);

        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(proveedorRepository.findByBodega_IdBodegaAndRuc(1L, "20601234567")).thenReturn(Optional.of(existente));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> proveedorService.crear(dto));
        assertTrue(ex.getMessage().contains("Ya existe un proveedor activo registrado con el RUC"));
        verify(proveedorRepository, never()).save(any(Proveedor.class));
    }

    @Test
    void testDesactivarProveedor_Exito() {
        Proveedor proveedor = new Proveedor();
        proveedor.setIdProveedor(5L);
        proveedor.setRuc("20123456789");
        proveedor.setEstado(true);

        when(tenantService.getCurrentBodegaId()).thenReturn(1L);
        when(proveedorRepository.findByIdProveedorAndBodega_IdBodega(5L, 1L)).thenReturn(Optional.of(proveedor));

        proveedorService.desactivar(5L);

        assertFalse(proveedor.getEstado());
        verify(proveedorRepository, times(1)).save(proveedor);
    }
}
