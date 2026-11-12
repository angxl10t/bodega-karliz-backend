package com.bodega.backend.config;

import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.UsuarioRepository;
import com.bodega.backend.service.StarterPackService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class DataInitializerSecurityTest {

    @Mock
    private JdbcTemplate jdbcTemplate;
    @Mock
    private BodegaRepository bodegaRepository;
    @Mock
    private UsuarioRepository usuarioRepository;
    @Mock
    private CategoriaRepository categoriaRepository;
    @Mock
    private ProductoRepository productoRepository;
    @Mock
    private PasswordEncoder passwordEncoder;
    @Mock
    private StarterPackService starterPackService;

    private DataInitializer dataInitializer;
    private Bodega bodega;

    @BeforeEach
    void setUp() {
        dataInitializer = new DataInitializer(
                jdbcTemplate,
                bodegaRepository,
                usuarioRepository,
                categoriaRepository,
                productoRepository,
                passwordEncoder,
                starterPackService
        );
        bodega = new Bodega();
        bodega.setIdBodega(1L);
        bodega.setNombreComercial("Bodega KARLIZ");
    }

    @Test
    void inicializarUsuarios_enProduccionSinSuperadminPassword_lanzaErrorAlCrearAdmin() {
        ReflectionTestUtils.setField(dataInitializer, "activeProfile", "prod");
        ReflectionTestUtils.setField(dataInitializer, "configuredSuperadminPassword", "");
        when(usuarioRepository.findByUsernameIgnoreCase("admin")).thenReturn(Optional.empty());

        IllegalStateException ex = assertThrows(IllegalStateException.class, () ->
                ReflectionTestUtils.invokeMethod(dataInitializer, "inicializarUsuarios", bodega));

        assertTrue(ex.getMessage().contains("SUPERADMIN_PASSWORD"));
        verify(usuarioRepository, never()).save(any());
    }

    @Test
    void inicializarUsuarios_enProduccionRechazaClaveDefault123456OCorta() {
        ReflectionTestUtils.setField(dataInitializer, "activeProfile", "prod");
        ReflectionTestUtils.setField(dataInitializer, "configuredSuperadminPassword", "123456");

        IllegalStateException ex = assertThrows(IllegalStateException.class, () ->
                ReflectionTestUtils.invokeMethod(dataInitializer, "inicializarUsuarios", bodega));

        assertTrue(ex.getMessage().contains("123456"));
        verify(usuarioRepository, never()).save(any());
    }

    @Test
    void inicializarUsuarios_enProduccionRotaClavePorDefectoSiSuperadminPasswordEstaConfigurada() {
        ReflectionTestUtils.setField(dataInitializer, "activeProfile", "prod");
        ReflectionTestUtils.setField(dataInitializer, "configuredSuperadminPassword", "SuperClaveSegura_2026!");

        Usuario existingAdmin = new Usuario();
        existingAdmin.setUsername("admin");
        existingAdmin.setPassword("$2a$10$oldDefaultHash");
        existingAdmin.setRol("ADMIN");

        when(usuarioRepository.findByUsernameIgnoreCase("admin")).thenReturn(Optional.of(existingAdmin));
        when(passwordEncoder.matches("123456", "$2a$10$oldDefaultHash")).thenReturn(true);
        when(passwordEncoder.encode("SuperClaveSegura_2026!")).thenReturn("encodedStrongHash");

        ReflectionTestUtils.invokeMethod(dataInitializer, "inicializarUsuarios", bodega);

        ArgumentCaptor<Usuario> captor = ArgumentCaptor.forClass(Usuario.class);
        verify(usuarioRepository).save(captor.capture());
        assertEquals("SUPERADMIN", captor.getValue().getRol());
        assertNull(captor.getValue().getBodega());
        assertEquals("encodedStrongHash", captor.getValue().getPassword());
        assertTrue(captor.getValue().getEstado());
    }

    @Test
    void inicializarUsuarios_enProduccionBloqueaCuentasDemoAunqueFlagEsteActivo() {
        ReflectionTestUtils.setField(dataInitializer, "activeProfile", "prod");
        ReflectionTestUtils.setField(dataInitializer, "configuredSuperadminPassword", "SuperClaveSegura_2026!");
        ReflectionTestUtils.setField(dataInitializer, "seedDemoAccountsRaw", "true");

        Usuario existingAdmin = new Usuario();
        existingAdmin.setUsername("admin");
        existingAdmin.setPassword("customAlreadyHashed");
        existingAdmin.setEstado(true);
        existingAdmin.setEmail("admin@cajaya.pe");

        when(usuarioRepository.findByUsernameIgnoreCase("admin")).thenReturn(Optional.of(existingAdmin));
        when(passwordEncoder.matches("123456", "customAlreadyHashed")).thenReturn(false);

        ReflectionTestUtils.invokeMethod(dataInitializer, "inicializarUsuarios", bodega);

        verify(usuarioRepository, never()).findByUsernameIgnoreCase("admin_karliz");
        verify(usuarioRepository, never()).findByUsernameIgnoreCase("cajero_karlizzz");
    }
}
