package com.bodega.backend.service;

import com.bodega.backend.dto.ReclamacionCreacionDTO;
import com.bodega.backend.dto.ReclamacionDTO;
import com.bodega.backend.dto.ReclamacionRespuestaDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Reclamacion;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.ReclamacionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ReclamacionServiceTest {

    @Mock
    private ReclamacionRepository reclamacionRepository;

    @Mock
    private BodegaRepository bodegaRepository;

    @Mock
    private TenantService tenantService;

    @InjectMocks
    private ReclamacionService reclamacionService;

    private Bodega bodega;

    @BeforeEach
    void setUp() {
        bodega = new Bodega();
        bodega.setIdBodega(1L);
        bodega.setNombreComercial("Bodega Karliz");
    }

    @Test
    void testRegistrarReclamacionExitosoConCorrelativoLegal() {
        when(bodegaRepository.findById(1L)).thenReturn(Optional.of(bodega));
        when(reclamacionRepository.obtenerSiguienteCorrelativo()).thenReturn(42L);

        when(reclamacionRepository.save(any(Reclamacion.class))).thenAnswer(inv -> {
            Reclamacion r = inv.getArgument(0);
            r.setIdReclamacion(10L);
            r.setFechaReclamo(OffsetDateTime.now());
            return r;
        });

        ReclamacionCreacionDTO dto = ReclamacionCreacionDTO.builder()
                .idBodega(1L)
                .nombreReclamante("Juan Perez")
                .tipoDocumento("DNI")
                .numeroDocumento("71234567")
                .email("juan.perez@gmail.com")
                .telefono("987654321")
                .direccion("Av. Los Pinos 123")
                .tipo("RECLAMO")
                .tipoBien("PRODUCTO")
                .montoReclamado(new BigDecimal("15.50"))
                .descripcionBien("Leche Gloria 1L")
                .detalleReclamacion("El producto presentaba fecha de vencimiento expirada al momento de la compra.")
                .pedidoReclamante("Cambio del producto o devolución del dinero.")
                .build();

        ReclamacionDTO res = reclamacionService.registrarReclamacion(dto);

        assertNotNull(res);
        assertTrue(res.getCodigoReclamacion().startsWith("REC-"));
        assertTrue(res.getCodigoReclamacion().endsWith("-00042"));
        assertEquals("PENDIENTE", res.getEstado());
        assertEquals("Juan Perez", res.getNombreReclamante());
        assertEquals("Bodega Karliz", res.getNombreBodega());
        assertEquals(15, res.getDiasHabilesRestantes());

        verify(reclamacionRepository, times(1)).save(any(Reclamacion.class));
    }

    @Test
    void testConsultarPorCodigoExitoso() {
        Reclamacion r = Reclamacion.builder()
                .idReclamacion(1L)
                .codigoReclamacion("REC-2026-00001")
                .bodega(bodega)
                .nombreReclamante("Maria Gomez")
                .tipoDocumento("DNI")
                .numeroDocumento("45678901")
                .email("maria@gmail.com")
                .tipo("QUEJA")
                .tipoBien("SERVICIO")
                .detalleReclamacion("Trato poco cordial en caja.")
                .pedidoReclamante("Disculpas del personal.")
                .estado("PENDIENTE")
                .fechaReclamo(OffsetDateTime.now())
                .build();

        when(reclamacionRepository.findByCodigoReclamacion("REC-2026-00001")).thenReturn(Optional.of(r));

        ReclamacionDTO res = reclamacionService.consultarPorCodigo("REC-2026-00001");
        assertNotNull(res);
        assertEquals("REC-2026-00001", res.getCodigoReclamacion());
        assertEquals("QUEJA", res.getTipo());
        // Consulta anónima pública enmascara datos sensibles PII
        assertEquals("45****01", res.getNumeroDocumento());
        assertEquals("m***a@gmail.com", res.getEmail());
        assertEquals("Maria G.", res.getNombreReclamante());

        // Consulta acreditando documento de identidad retorna datos completos
        ReclamacionDTO unmasked = reclamacionService.consultarPorCodigo("REC-2026-00001", "45678901");
        assertEquals("45678901", unmasked.getNumeroDocumento());
        assertEquals("maria@gmail.com", unmasked.getEmail());
        assertEquals("Maria Gomez", unmasked.getNombreReclamante());
    }

    @Test
    void testResponderReclamacionComoAdminBodega() {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken("admin", "pass", List.of(new SimpleGrantedAuthority("ROLE_ADMIN")))
        );

        when(tenantService.getCurrentBodegaId()).thenReturn(1L);

        Reclamacion r = Reclamacion.builder()
                .idReclamacion(5L)
                .codigoReclamacion("REC-2026-00005")
                .bodega(bodega)
                .nombreReclamante("Carlos Quispe")
                .tipoDocumento("DNI")
                .numeroDocumento("12345678")
                .email("carlos@gmail.com")
                .tipo("RECLAMO")
                .estado("PENDIENTE")
                .fechaReclamo(OffsetDateTime.now().minusDays(2))
                .build();

        when(reclamacionRepository.findById(5L)).thenReturn(Optional.of(r));
        when(reclamacionRepository.save(any(Reclamacion.class))).thenAnswer(inv -> inv.getArgument(0));

        ReclamacionRespuestaDTO respDTO = ReclamacionRespuestaDTO.builder()
                .respuestaProveedor("Estimado cliente, se procedió con la devolución íntegra del dinero en efectivo.")
                .nuevoEstado("ATENDIDO")
                .build();

        ReclamacionDTO res = reclamacionService.responderReclamacion(5L, respDTO);
        assertNotNull(res);
        assertEquals("ATENDIDO", res.getEstado());
        assertEquals("Estimado cliente, se procedió con la devolución íntegra del dinero en efectivo.", res.getRespuestaProveedor());
        assertNotNull(res.getFechaRespuesta());
        assertEquals(0, res.getDiasHabilesRestantes());

        SecurityContextHolder.clearContext();
    }
}
