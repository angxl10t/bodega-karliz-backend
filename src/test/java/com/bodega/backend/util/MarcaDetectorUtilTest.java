package com.bodega.backend.util;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class MarcaDetectorUtilTest {

    @Test
    @DisplayName("Detecta marcas canónicas comunes en nombres de productos peruanos")
    void testDetectarMarcasComunes() {
        assertEquals("Pepsi", MarcaDetectorUtil.detectarMarca("Gaseosa Pepsi 1.5L descartable"));
        assertEquals("Inca Kola", MarcaDetectorUtil.detectarMarca("Inca Kola Sin Azúcar 500ml"));
        assertEquals("Inca Kola", MarcaDetectorUtil.detectarMarca("Inka Kola Sabor Original 3L"));
        assertEquals("Coca-Cola", MarcaDetectorUtil.detectarMarca("Coca Cola 500ml botella"));
        assertEquals("Coca-Cola", MarcaDetectorUtil.detectarMarca("Coca-Cola 3 Litros descartable"));
        assertEquals("Bimbo", MarcaDetectorUtil.detectarMarca("Pan Molde Bimbo Blanco Familiar"));
        assertEquals("D'Onofrio", MarcaDetectorUtil.detectarMarca("Helado Sandwich D'Onofrio"));
        assertEquals("AlaCena", MarcaDetectorUtil.detectarMarca("Mayonesa AlaCena Doypack 400g"));
        assertEquals("AlaCena", MarcaDetectorUtil.detectarMarca("Salsa Alacena Tari Picante"));
        assertEquals("Molitalia", MarcaDetectorUtil.detectarMarca("Fideos Spaghetti Molitalia 500g"));
        assertEquals("Gloria", MarcaDetectorUtil.detectarMarca("Leche Evaporada Gloria Azul 400g"));
        assertEquals("Elite", MarcaDetectorUtil.detectarMarca("Papel Higiénico Elite Dúo 4 rollos"));
        assertEquals("Paracas", MarcaDetectorUtil.detectarMarca("Papel Higiénico Paracas Black"));
        assertEquals("Pilsen Callao", MarcaDetectorUtil.detectarMarca("Cerveza Pilsen Callao 310ml"));
        assertEquals("Sublime", MarcaDetectorUtil.detectarMarca("Chocolate Sublime Clásico 30g"));
    }

    @Test
    @DisplayName("Normaliza variantes de mayúsculas y acentos a forma canónica")
    void testNormalizarMarcas() {
        assertEquals("AlaCena", MarcaDetectorUtil.normalizarMarca("alacena"));
        assertEquals("Pepsi", MarcaDetectorUtil.normalizarMarca("PEPSI"));
        assertEquals("Lay's", MarcaDetectorUtil.normalizarMarca("lays"));
        assertEquals("D'Onofrio", MarcaDetectorUtil.normalizarMarca("donofrio"));
        assertEquals("Inca Kola", MarcaDetectorUtil.normalizarMarca("inca kola"));
        assertEquals("Bimbo", MarcaDetectorUtil.normalizarMarca("bimbo"));
        // Marca no registrada recibe capitalización limpia
        assertEquals("Marca Nueva Peru", MarcaDetectorUtil.normalizarMarca("marca nueva peru"));
    }

    @Test
    @DisplayName("Retorna null si no se detecta ninguna marca o string vacío")
    void testCasosVacios() {
        assertNull(MarcaDetectorUtil.detectarMarca(null));
        assertNull(MarcaDetectorUtil.detectarMarca("   "));
        assertNull(MarcaDetectorUtil.detectarMarca("Manzana delicia por kilo"));
        assertNull(MarcaDetectorUtil.normalizarMarca(null));
        assertNull(MarcaDetectorUtil.normalizarMarca("   "));
    }
}
