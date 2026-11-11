package com.bodega.backend.service;

import com.bodega.backend.dto.PromocionDTO;
import com.bodega.backend.dto.SugerenciaComboHuesoDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.entity.Promocion;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.PromocionRepository;
import com.bodega.backend.repository.VentaDetalleRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;
import org.springframework.security.access.AccessDeniedException;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.*;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PromocionServiceTest {

    @Mock
    private PromocionRepository promocionRepository;

    @Mock
    private ProductoRepository productoRepository;

    @Mock
    private VentaDetalleRepository ventaDetalleRepository;

    @Mock
    private TenantService tenantService;

    @InjectMocks
    private PromocionService promocionService;

    private Bodega bodegaPro;
    private Bodega bodegaBasico;

    @BeforeEach
    void setUp() {
        bodegaPro = new Bodega();
        bodegaPro.setIdBodega(3L);
        bodegaPro.setNombreComercial("Bodega KARLIZ");
        bodegaPro.setPlan("PRO");
        bodegaPro.setEstado(true);

        bodegaBasico = new Bodega();
        bodegaBasico.setIdBodega(4L);
        bodegaBasico.setNombreComercial("Bodega Don Pepe");
        bodegaBasico.setPlan("BASICO");
        bodegaBasico.setEstado(true);
    }

    @Test
    @DisplayName("Debe bloquear acceso al módulo de promociones si el plan es BASICO")
    void testBloqueoPlanBasico() {
        when(tenantService.getCurrentBodega()).thenReturn(bodegaBasico);

        assertThatThrownBy(() -> promocionService.listarPromociones())
                .isInstanceOf(AccessDeniedException.class)
                .hasMessageContaining("Plan Minimarket PRO");

        verify(promocionRepository, never()).findByBodega_IdBodegaOrderByFechaCreacionDesc(any());
    }

    @Test
    @DisplayName("Debe permitir listar promociones si la bodega cuenta con Plan PRO")
    void testListarPromocionesPro() {
        when(tenantService.getCurrentBodega()).thenReturn(bodegaPro);

        Promocion promo = Promocion.builder()
                .idPromocion(1L)
                .bodega(bodegaPro)
                .titulo("15% en Bebidas")
                .alcance("CATEGORIA")
                .categoriaObjetivo("Bebidas")
                .tipoPromocion("PORCENTAJE")
                .valorDescuento(new BigDecimal("15"))
                .activo(true)
                .build();

        when(promocionRepository.findByBodega_IdBodegaOrderByFechaCreacionDesc(3L))
                .thenReturn(List.of(promo));

        List<PromocionDTO> resultado = promocionService.listarPromociones();

        assertThat(resultado).hasSize(1);
        assertThat(resultado.get(0).getTitulo()).isEqualTo("15% en Bebidas");
        assertThat(resultado.get(0).getValorDescuento()).isEqualByComparingTo("15");
    }

    @Test
    @DisplayName("Debe crear una nueva promoción individual vinculada estrictamente al ID de bodega")
    void testCrearPromocion() {
        when(tenantService.getCurrentBodega()).thenReturn(bodegaPro);

        PromocionDTO dto = PromocionDTO.builder()
                .titulo("Promo Pepsi 2x1")
                .alcance("MARCA")
                .marcaObjetivo("Pepsi")
                .tipoPromocion("DOS_POR_UNO")
                .badgeTexto("🏷️ 2x1")
                .build();

        when(promocionRepository.save(any(Promocion.class))).thenAnswer(inv -> {
            Promocion p = inv.getArgument(0);
            p.setIdPromocion(10L);
            return p;
        });

        PromocionDTO creado = promocionService.crearPromocion(dto);

        assertThat(creado.getIdPromocion()).isEqualTo(10L);
        assertThat(creado.getTitulo()).isEqualTo("Promo Pepsi 2x1");
        assertThat(creado.getIdBodega()).isEqualTo(3L);
        verify(promocionRepository).save(any(Promocion.class));
    }

    @Test
    @DisplayName("Debe alternar el estado activo/pausado de la promoción")
    void testCambiarEstadoPromocion() {
        when(tenantService.getCurrentBodega()).thenReturn(bodegaPro);

        Promocion promo = Promocion.builder()
                .idPromocion(5L)
                .bodega(bodegaPro)
                .titulo("Descuento Galletas")
                .activo(true)
                .build();

        when(promocionRepository.findByIdPromocionAndBodega_IdBodega(5L, 3L))
                .thenReturn(Optional.of(promo));
        when(promocionRepository.save(any(Promocion.class))).thenAnswer(inv -> inv.getArgument(0));

        PromocionDTO actualizado = promocionService.cambiarEstado(5L, false);

        assertThat(actualizado.getActivo()).isFalse();
    }

    @Test
    @DisplayName("Debe generar sugerencias inteligentes combinando productos Hueso con Estrellas")
    void testObtenerSugerenciasCombosHueso() {
        when(tenantService.getCurrentBodega()).thenReturn(bodegaPro);

        Object[] rawHueso = new Object[]{101L, "Piqueo Especial", "PIQ01", "Snacks", "snack.png", new BigDecimal("20"), new BigDecimal("3.00"), new BigDecimal("60.00"), null};
        List<Object[]> listHuesos = Collections.singletonList(rawHueso);
        when(productoRepository.findProductosHuesoByPeriodo(eq(3L), any(OffsetDateTime.class), any(Pageable.class)))
                .thenReturn(listHuesos);

        Object[] rawEstrella = new Object[]{202L, "Coca-Cola 500ml", "COC01", "Bebidas", "coca.png", new BigDecimal("50"), new BigDecimal("175.00"), new BigDecimal("125.00")};
        List<Object[]> listEstrellas = Collections.singletonList(rawEstrella);
        when(ventaDetalleRepository.findTopEstrellasByPeriodo(eq(3L), any(OffsetDateTime.class), any(Pageable.class)))
                .thenReturn(listEstrellas);

        Producto prodHueso = new Producto();
        prodHueso.setIdProducto(101L);
        prodHueso.setNombre("Piqueo Especial");
        prodHueso.setPrecioVenta(new BigDecimal("4.50"));

        Producto prodEstrella = new Producto();
        prodEstrella.setIdProducto(202L);
        prodEstrella.setNombre("Coca-Cola 500ml");
        prodEstrella.setPrecioVenta(new BigDecimal("3.50"));
        when(productoRepository.findAllById(anyIterable())).thenReturn(List.of(prodHueso, prodEstrella));

        List<SugerenciaComboHuesoDTO> sugerencias = promocionService.obtenerSugerenciasCombosHueso();

        verify(productoRepository, times(1)).findAllById(anyIterable());
        verify(productoRepository, never()).findById(anyLong());
        verify(productoRepository, never()).findByBodega_IdBodegaAndEstadoTrue(anyLong());

        assertThat(sugerencias).isNotEmpty();
        SugerenciaComboHuesoDTO combo = sugerencias.get(0);
        assertThat(combo.getIdProductoHueso()).isEqualTo(101L);
        assertThat(combo.getIdProductoEstrella()).isEqualTo(202L);
        assertThat(combo.getPrecioRegularTotal()).isEqualByComparingTo("8.00");
        assertThat(combo.getPrecioComboSugerido()).isLessThan(new BigDecimal("8.00"));
        assertThat(combo.getRazonEstrategica()).contains("Libera S/ 60.00 inmovilizados");
    }
}
