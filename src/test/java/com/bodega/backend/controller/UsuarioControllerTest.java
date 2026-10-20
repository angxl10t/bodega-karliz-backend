package com.bodega.backend.controller;

import com.bodega.backend.dto.UsuarioDTO;
import com.bodega.backend.service.UsuarioService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.security.Principal;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class UsuarioControllerTest {

    @Mock
    private UsuarioService usuarioService;

    @Mock
    private Principal principal;

    @InjectMocks
    private UsuarioController usuarioController;

    private UsuarioDTO usuarioDTO;

    @BeforeEach
    void setUp() {
        usuarioDTO = new UsuarioDTO();
        usuarioDTO.setIdUsuario(2L);
        usuarioDTO.setUsername("cajero1");
        usuarioDTO.setNombreCompleto("Pedro Cajero");
        usuarioDTO.setRol("CAJERO");
        usuarioDTO.setEstado(true);
    }

    @Test
    void testListarTodos() {
        when(usuarioService.listarTodos()).thenReturn(List.of(usuarioDTO));

        ResponseEntity<List<UsuarioDTO>> response = usuarioController.listarTodos();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(1, response.getBody().size());
        assertEquals("cajero1", response.getBody().get(0).getUsername());
    }

    @Test
    void testCrearUsuario() {
        when(usuarioService.crearUsuario(any(UsuarioDTO.class))).thenReturn(usuarioDTO);

        ResponseEntity<UsuarioDTO> response = usuarioController.crearUsuario(usuarioDTO);

        assertNotNull(response);
        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertEquals(2L, response.getBody().getIdUsuario());
        verify(usuarioService).crearUsuario(any(UsuarioDTO.class));
    }

    @Test
    void testCambiarEstado() {
        when(principal.getName()).thenReturn("admin");
        when(usuarioService.cambiarEstado(2L, false, "admin")).thenReturn(usuarioDTO);

        ResponseEntity<UsuarioDTO> response = usuarioController.cambiarEstado(2L, false, principal);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(usuarioService).cambiarEstado(2L, false, "admin");
    }

    @Test
    void testResetearPassword() {
        when(principal.getName()).thenReturn("admin");
        doNothing().when(usuarioService).resetearPassword(2L, "nuevaClave123", "admin");

        ResponseEntity<Map<String, String>> response = usuarioController.resetearPassword(
                2L,
                Map.of("nuevaPassword", "nuevaClave123"),
                principal
        );

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertTrue(response.getBody().get("mensaje").contains("restablecida"));
        verify(usuarioService).resetearPassword(2L, "nuevaClave123", "admin");
    }
}
