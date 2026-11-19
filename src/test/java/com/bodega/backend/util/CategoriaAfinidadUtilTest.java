package com.bodega.backend.util;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class CategoriaAfinidadUtilTest {

    @Test
    @DisplayName("Debe detectar correctamente familias de productos")
    void testDetectarFamilias() {
        assertThat(CategoriaAfinidadUtil.detectarFamilia("Snacks", "Tortees Sal Picante 150g"))
                .isEqualTo(CategoriaAfinidadUtil.FAM_SNACKS);

        assertThat(CategoriaAfinidadUtil.detectarFamilia("Bebidas", "Gaseosa Inka Kola 500ml"))
                .isEqualTo(CategoriaAfinidadUtil.FAM_BEBIDAS);

        assertThat(CategoriaAfinidadUtil.detectarFamilia("Licores", "Cerveza Cusqueña Trigo 620ml"))
                .isEqualTo(CategoriaAfinidadUtil.FAM_CERVEZAS);

        assertThat(CategoriaAfinidadUtil.detectarFamilia("Mascotas", "Comida para Perro Ricocan 1kg"))
                .isEqualTo(CategoriaAfinidadUtil.FAM_MASCOTAS);

        assertThat(CategoriaAfinidadUtil.detectarFamilia("Limpieza", "Detergente Ace Floral 500g"))
                .isEqualTo(CategoriaAfinidadUtil.FAM_LIMPIEZA);

        assertThat(CategoriaAfinidadUtil.detectarFamilia("Lácteos", "Leche Gloria Azul 400g"))
                .isEqualTo(CategoriaAfinidadUtil.FAM_DESAYUNO);

        assertThat(CategoriaAfinidadUtil.detectarFamilia("Golosinas", "Galleta Pícaras Chocolate 40g"))
                .isEqualTo(CategoriaAfinidadUtil.FAM_GOLOSINAS);

        assertThat(CategoriaAfinidadUtil.detectarFamilia("Abarrotes", "Fideos Molitalia Spaghetti 500g"))
                .isEqualTo(CategoriaAfinidadUtil.FAM_ABARROTES);
    }

    @Test
    @DisplayName("Debe rechazar estrictamente combinaciones absurdas (Puntaje 0)")
    void testCombinacionesIncompatibles() {
        // Cerveza + Comida de perro: Estrictamente 0
        int afinidadCervezaMascota = CategoriaAfinidadUtil.evaluarAfinidad(
                CategoriaAfinidadUtil.FAM_CERVEZAS, CategoriaAfinidadUtil.FAM_MASCOTAS);
        assertThat(afinidadCervezaMascota).isEqualTo(0);

        // Detergente / Limpieza + Alimentos: Estrictamente 0
        int afinidadLimpiezaSnack = CategoriaAfinidadUtil.evaluarAfinidad(
                CategoriaAfinidadUtil.FAM_LIMPIEZA, CategoriaAfinidadUtil.FAM_SNACKS);
        assertThat(afinidadLimpiezaSnack).isEqualTo(0);

        int afinidadLimpiezaBebida = CategoriaAfinidadUtil.evaluarAfinidad(
                CategoriaAfinidadUtil.FAM_LIMPIEZA, CategoriaAfinidadUtil.FAM_BEBIDAS);
        assertThat(afinidadLimpiezaBebida).isEqualTo(0);

        // Cerveza con lácteos / desayuno: Estrictamente 0
        int afinidadCervezaLacteo = CategoriaAfinidadUtil.evaluarAfinidad(
                CategoriaAfinidadUtil.FAM_CERVEZAS, CategoriaAfinidadUtil.FAM_DESAYUNO);
        assertThat(afinidadCervezaLacteo).isEqualTo(0);
    }

    @Test
    @DisplayName("Debe calificar con alta afinidad las ocasiones típicas de consumo bodeguero")
    void testCombinacionesAfines() {
        // Tortees (Snack) + Gaseosa: 100% afinidad
        int afinidadSnackBebida = CategoriaAfinidadUtil.evaluarAfinidad(
                CategoriaAfinidadUtil.FAM_SNACKS, CategoriaAfinidadUtil.FAM_BEBIDAS);
        assertThat(afinidadSnackBebida).isEqualTo(100);

        // Cerveza + Piqueo/Snack: 100% afinidad
        int afinidadCervezaSnack = CategoriaAfinidadUtil.evaluarAfinidad(
                CategoriaAfinidadUtil.FAM_CERVEZAS, CategoriaAfinidadUtil.FAM_SNACKS);
        assertThat(afinidadCervezaSnack).isEqualTo(100);

        // Desayuno (Leche) + Galletas dulces: 95% afinidad
        int afinidadLecheGalleta = CategoriaAfinidadUtil.evaluarAfinidad(
                CategoriaAfinidadUtil.FAM_DESAYUNO, CategoriaAfinidadUtil.FAM_GOLOSINAS);
        assertThat(afinidadLecheGalleta).isEqualTo(95);

        // Abarrotes + Abarrotes (Fideos + Salsa / Atún): 100% afinidad
        int afinidadAbarrotes = CategoriaAfinidadUtil.evaluarAfinidad(
                CategoriaAfinidadUtil.FAM_ABARROTES, CategoriaAfinidadUtil.FAM_ABARROTES);
        assertThat(afinidadAbarrotes).isEqualTo(100);
    }

    @Test
    @DisplayName("Debe generar etiquetas estratégicas adecuadas para combos afines")
    void testEtiquetasAfinidad() {
        assertThat(CategoriaAfinidadUtil.obtenerEtiquetaAfinidad(CategoriaAfinidadUtil.FAM_CERVEZAS, CategoriaAfinidadUtil.FAM_SNACKS))
                .isEqualTo("🍻 PIQUEO & BRINDIS");

        assertThat(CategoriaAfinidadUtil.obtenerEtiquetaAfinidad(CategoriaAfinidadUtil.FAM_SNACKS, CategoriaAfinidadUtil.FAM_BEBIDAS))
                .isEqualTo("🍿 SNACK & GASEOSA");

        assertThat(CategoriaAfinidadUtil.obtenerEtiquetaAfinidad(CategoriaAfinidadUtil.FAM_ABARROTES, CategoriaAfinidadUtil.FAM_ABARROTES))
                .isEqualTo("🥫 ALMUERZO BODEGUERO");

        assertThat(CategoriaAfinidadUtil.obtenerEtiquetaAfinidad(CategoriaAfinidadUtil.FAM_DESAYUNO, CategoriaAfinidadUtil.FAM_GOLOSINAS))
                .isEqualTo("☕ DESAYUNO & LONCHE");
    }
}
