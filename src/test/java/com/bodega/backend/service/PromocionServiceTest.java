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
        assertThat(combo.getSeccionSugerencia()).isEqualTo("HUESO_ESTRELLA");
        assertThat(combo.getTipoAfinidad()).isEqualTo("🍿 SNACK & GASEOSA");
        assertThat(combo.getImpactoMargen()).contains("Margen de Coca-Cola 500ml (estrella) protegido al 100%");
    }

    @Test
    @DisplayName("Debe rechazar combinaciones absurdas e incompatibles como Cerveza con Comida de Perro")
    void testRechazaCombinacionesIncompatiblesComoCervezaYComidaPerro() {
        when(tenantService.getCurrentBodega()).thenReturn(bodegaPro);

        // Hueso: Comida para perro
        Object[] rawHueso = new Object[]{301L, "Ricocan Adultos Carne 1kg", "RIC01", "Mascotas", "ricocan.png", new BigDecimal("15"), new BigDecimal("7.50"), new BigDecimal("112.50"), null};
        List<Object[]> listHuesos = new ArrayList<>();
        listHuesos.add(rawHueso);
        when(productoRepository.findProductosHuesoByPeriodo(eq(3L), any(OffsetDateTime.class), any(Pageable.class)))
                .thenReturn(listHuesos);

        // Estrella: Cerveza
        Object[] rawEstrella = new Object[]{402L, "Cerveza Pilsen Callao 630ml", "CER01", "Licores", "pilsen.png", new BigDecimal("80"), new BigDecimal("560.00"), new BigDecimal("160.00")};
        List<Object[]> listEstrellas = new ArrayList<>();
        listEstrellas.add(rawEstrella);
        when(ventaDetalleRepository.findTopEstrellasByPeriodo(eq(3L), any(OffsetDateTime.class), any(Pageable.class)))
                .thenReturn(listEstrellas);

        Producto prodHueso = new Producto();
        prodHueso.setIdProducto(301L);
        prodHueso.setNombre("Ricocan Adultos Carne 1kg");
        prodHueso.setPrecioVenta(new BigDecimal("10.50"));

        Producto prodEstrella = new Producto();
        prodEstrella.setIdProducto(402L);
        prodEstrella.setNombre("Cerveza Pilsen Callao 630ml");
        prodEstrella.setPrecioVenta(new BigDecimal("7.00"));

        when(productoRepository.findAllById(anyIterable())).thenReturn(List.of(prodHueso, prodEstrella));

        List<SugerenciaComboHuesoDTO> sugerencias = promocionService.obtenerSugerenciasCombosHueso();

        // Debe descartar el emparejamiento Cerveza + Comida de perro por ser incompatible (afinidad 0)
        assertThat(sugerencias).noneMatch(s ->
                (s.getNombreHueso().contains("Ricocan") && s.getNombreEstrella().contains("Pilsen")) ||
                (s.getNombreHueso().contains("Pilsen") && s.getNombreEstrella().contains("Ricocan")));
    }

    @Test
    @DisplayName("Debe generar sugerencias de múltiples secciones con productos que salen y otros que no")
    void testGeneraSugerenciasMultiplesSecciones() {
        when(tenantService.getCurrentBodega()).thenReturn(bodegaPro);

        // 2 Huesos afines de abarrotes
        Object[] h1 = new Object[]{501L, "Fideos Spaghetti Molitalia 500g", "FID01", "Abarrotes", "fideo.png", new BigDecimal("30"), new BigDecimal("2.00"), new BigDecimal("60.00"), null};
        Object[] h2 = new Object[]{502L, "Salsa de Tomate Pomarola 150g", "SAL01", "Abarrotes", "salsa.png", new BigDecimal("25"), new BigDecimal("1.50"), new BigDecimal("37.50"), null};
        List<Object[]> listHuesos = new ArrayList<>();
        listHuesos.add(h1);
        listHuesos.add(h2);
        when(productoRepository.findProductosHuesoByPeriodo(eq(3L), any(OffsetDateTime.class), any(Pageable.class)))
                .thenReturn(listHuesos);

        // 2 Estrellas afines de bebidas y snacks
        Object[] e1 = new Object[]{601L, "Cerveza Cristal 650ml", "CER02", "Licores", "cristal.png", new BigDecimal("60"), new BigDecimal("420.00"), new BigDecimal("120.00")};
        Object[] e2 = new Object[]{602L, "Piqueo Snax Familiar 200g", "SNX01", "Snacks", "snax.png", new BigDecimal("40"), new BigDecimal("240.00"), new BigDecimal("80.00")};
        List<Object[]> listEstrellas = new ArrayList<>();
        listEstrellas.add(e1);
        listEstrellas.add(e2);
        when(ventaDetalleRepository.findTopEstrellasByPeriodo(eq(3L), any(OffsetDateTime.class), any(Pageable.class)))
                .thenReturn(listEstrellas);

        Producto p501 = new Producto(); p501.setIdProducto(501L); p501.setNombre("Fideos Spaghetti Molitalia 500g"); p501.setPrecioVenta(new BigDecimal("2.80"));
        Producto p502 = new Producto(); p502.setIdProducto(502L); p502.setNombre("Salsa de Tomate Pomarola 150g"); p502.setPrecioVenta(new BigDecimal("2.20"));
        Producto p601 = new Producto(); p601.setIdProducto(601L); p601.setNombre("Cerveza Cristal 650ml"); p601.setPrecioVenta(new BigDecimal("7.00"));
        Producto p602 = new Producto(); p602.setIdProducto(602L); p602.setNombre("Piqueo Snax Familiar 200g"); p602.setPrecioVenta(new BigDecimal("6.00"));

        when(productoRepository.findAllById(anyIterable())).thenReturn(List.of(p501, p502, p601, p602));

        List<SugerenciaComboHuesoDTO> sugerencias = promocionService.obtenerSugerenciasCombosHueso();

        assertThat(sugerencias).isNotEmpty();

        // Verificar sección ALTA_ROTACION (Cerveza + Piqueo Snax)
        boolean hasAltaRotacion = sugerencias.stream().anyMatch(s ->
                "ALTA_ROTACION".equals(s.getSeccionSugerencia()) &&
                s.getBadgeSugerido().contains("DUO ESTRELLA") &&
                s.getImpactoMargen().contains("Descuento ligero (7%)"));
        assertThat(hasAltaRotacion).isTrue();

        // Verificar sección LIQUIDACION_PAREJA (Fideos + Salsa)
        boolean hasLiquidacion = sugerencias.stream().anyMatch(s ->
                "LIQUIDACION_PAREJA".equals(s.getSeccionSugerencia()) &&
                s.getBadgeSugerido().contains("PACK CLEARANCE") &&
                s.getImpactoMargen().contains("Liquidación conjunta de 2 productos dormidos"));
        assertThat(hasLiquidacion).isTrue();
    }
}
