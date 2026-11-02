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
    @DisplayName("Evalúa coincidencia de marca en promociones con tolerancia exhaustiva a guiones, acentos y variantes")
    void testCoincidenciaMarcaPromociones() {
        // 1. Coca-Cola (con guión, sin guión, minúsculas, mayúsculas, en marca o en nombre)
        assertTrue(MarcaDetectorUtil.coincideMarca("Coca-Cola", "Coca Cola", "Coca Cola 500ml botella"));
        assertTrue(MarcaDetectorUtil.coincideMarca("coca cola", "Coca-Cola", "Coca Cola Sabor Original 3 Litros"));
        assertTrue(MarcaDetectorUtil.coincideMarca("Coca Cola", "Coca Cola", "Gaseosa 500ml"));
        assertTrue(MarcaDetectorUtil.coincideMarca("Coca-Cola", null, "Coca Cola 1.5L descartable"));
        assertTrue(MarcaDetectorUtil.coincideMarca("Coca Cola", "", "Coca-Cola Zero 500ml"));

        // 2. Lay's / Lays / Frito-Lay
        assertTrue(MarcaDetectorUtil.coincideMarca("Lay's", "Lays", "Papas Lays Clásicas 160g"));
        assertTrue(MarcaDetectorUtil.coincideMarca("Lays", "Lay's", "Papas Fritas Ondas 150g"));
        assertTrue(MarcaDetectorUtil.coincideMarca("Lay's", "Frito-Lay", "Papas Lay's Al Hilo 100g"));

        // 3. 7Up / 7 Up / 7-Up
        assertTrue(MarcaDetectorUtil.coincideMarca("7Up", "7 Up", "Gaseosa 7 Up 500ml"));
        assertTrue(MarcaDetectorUtil.coincideMarca("7 Up", "7Up", "Gaseosa 7-Up 3L"));

        // 4. D'Onofrio / Donofrio
        assertTrue(MarcaDetectorUtil.coincideMarca("D'Onofrio", "Donofrio", "Helado Sandwich D'Onofrio"));
        assertTrue(MarcaDetectorUtil.coincideMarca("donofrio", "D'Onofrio", "Helado Jet Paleta"));

        // 5. Inca Kola / Inka Kola
        assertTrue(MarcaDetectorUtil.coincideMarca("Inca Kola", "Inka Kola", "Inca Kola 500ml"));
        assertTrue(MarcaDetectorUtil.coincideMarca("Inka Kola", "Inca Kola", "Inka Kola Sabor Original 3L"));

        // 6. Marlboro / Malboro
        assertTrue(MarcaDetectorUtil.coincideMarca("Marlboro", "Malboro", "Malboro Gold Box 20"));
        assertTrue(MarcaDetectorUtil.coincideMarca("Malboro", "Marlboro", "Cigarrillos Marlboro"));

        // 7. San Mateo / San Luis / Pilsen Callao
        assertTrue(MarcaDetectorUtil.coincideMarca("San Mateo", "San-Mateo", "Agua Mineral San Mateo 600ml"));
        assertTrue(MarcaDetectorUtil.coincideMarca("San Luis", "San-Luis", "Agua San Luis 625ml"));
        assertTrue(MarcaDetectorUtil.coincideMarca("Pilsen", "Pilsen Callao", "Cerveza Pilsen Callao 310ml"));

        // 8. Acentos y diacríticos: Ángel / Bolívar / AlaCena / Nestlé
        assertTrue(MarcaDetectorUtil.coincideMarca("Ángel", "Angel", "Cereal Angel Flakes 250g"));
        assertTrue(MarcaDetectorUtil.coincideMarca("Bolívar", "Bolivar", "Detergente Bolivar 900g"));
        assertTrue(MarcaDetectorUtil.coincideMarca("AlaCena", "Alacena", "Mayonesa Alacena 400g"));
        assertTrue(MarcaDetectorUtil.coincideMarca("Nestlé", "Nestle", "Chocolate Nestle"));

        // 9. Casos Negativos (marcas diferentes nunca deben coincidir)
        assertFalse(MarcaDetectorUtil.coincideMarca("Coca-Cola", "Inca Kola", "Inca Kola Sabor Original 500ml"));
        assertFalse(MarcaDetectorUtil.coincideMarca("Pepsi", "Coca Cola", "Coca Cola 3 Litros"));
        assertFalse(MarcaDetectorUtil.coincideMarca("Bimbo", "Molitalia", "Fideos Spaghetti Molitalia 500g"));
        assertFalse(MarcaDetectorUtil.coincideMarca(null, "Coca Cola", "Coca Cola 500ml"));
        assertFalse(MarcaDetectorUtil.coincideMarca("   ", "Coca Cola", "Coca Cola 500ml"));
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
