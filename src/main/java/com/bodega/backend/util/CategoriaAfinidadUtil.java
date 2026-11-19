package com.bodega.backend.util;

import java.util.Locale;

/**
 * Utilidad de inteligencia comercial para afinar coherencia semántica en combos bodegueros.
 * Evita combinaciones absurdas (ej: Cerveza con comida de perro, o Detergente con alimentos)
 * y potencia canastas de compra cruzada habituales en bodegas peruanas.
 */
public final class CategoriaAfinidadUtil {

    private CategoriaAfinidadUtil() {}

    public static final String FAM_BEBIDAS = "BEBIDAS_REFRESCOS";
    public static final String FAM_CERVEZAS = "CERVEZAS_LICORES";
    public static final String FAM_SNACKS = "SNACKS_PIQUEOS";
    public static final String FAM_GOLOSINAS = "GOLOSINAS_DULCES";
    public static final String FAM_ABARROTES = "ABARROTES_ALMUERZO";
    public static final String FAM_DESAYUNO = "DESAYUNO_LACTEOS";
    public static final String FAM_LIMPIEZA = "LIMPIEZA_HOGAR";
    public static final String FAM_CUIDADO = "CUIDADO_PERSONAL";
    public static final String FAM_MASCOTAS = "MASCOTAS";
    public static final String FAM_GENERAL = "GENERAL";

    /**
     * Normaliza y detecta la familia de producto a partir de su categoría y nombre comercial.
     */
    public static String detectarFamilia(String categoria, String nombre) {
        String texto = ((categoria != null ? categoria : "") + " " + (nombre != null ? nombre : "")).toLowerCase(Locale.ROOT);
        texto = texto.replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("ñ", "n");

        if (texto.contains("perro") || texto.contains("gato") || texto.contains("ricocan") ||
                texto.contains("mimaskot") || texto.contains("ricocat") || texto.contains("whiskas") ||
                texto.contains("mascota") || texto.contains("canin") || texto.contains("felin")) {
            return FAM_MASCOTAS;
        }

        if (texto.contains("detergente") || texto.contains("ace") || texto.contains("ariel") ||
                texto.contains("bolivar") || texto.contains("suavizante") || texto.contains("downy") ||
                texto.contains("lavavajilla") || texto.contains("sapolio") || texto.contains("clorox") ||
                texto.contains("lejia") || texto.contains("higienico") || texto.contains("limpieza") ||
                texto.contains("paracas") || texto.contains("elite")) {
            return FAM_LIMPIEZA;
        }

        if (texto.contains("shampoo") || texto.contains("kolynos") || texto.contains("dento") ||
                texto.contains("pasta dental") || texto.contains("cepillo") || texto.contains("desodorante") ||
                texto.contains("jabon tocador") || texto.contains("cuidado personal")) {
            return FAM_CUIDADO;
        }

        if (texto.contains("cervez") || texto.contains("pilsen") || texto.contains("cristal") ||
                texto.contains("cusquena") || texto.contains("corona") || texto.contains("heineken") ||
                texto.contains("licor") || texto.contains("ron") || texto.contains("pisco") ||
                texto.contains("whisky") || texto.contains("vino") || texto.contains("vodka") ||
                texto.contains("smirnoff") || texto.contains("alcohol")) {
            return FAM_CERVEZAS;
        }

        if (texto.contains("tortees") || texto.contains("piqueo") || texto.contains("chifle") ||
                texto.contains("inka chips") || texto.contains("dorito") || texto.contains("lays") ||
                texto.contains("cheetos") || texto.contains("mani") || texto.contains("snack") ||
                texto.contains("salada") || texto.contains("chizito")) {
            return FAM_SNACKS;
        }

        if (texto.contains("gaseosa") || texto.contains("coca") || texto.contains("pepsi") ||
                texto.contains("inka kola") || texto.contains("inca kola") || texto.contains("seven up") ||
                texto.contains("7up") || texto.contains("sprite") || texto.contains("fanta") ||
                texto.contains("agua") || texto.contains("san luis") || texto.contains("cielo") ||
                texto.contains("rehidratante") || texto.contains("powerade") || texto.contains("gatorade") ||
                texto.contains("frugos") || texto.contains("pulp") || texto.contains("jugo") ||
                texto.contains("nectar") || texto.contains("concordia") || texto.contains("bebida")) {
            return FAM_BEBIDAS;
        }

        if (texto.contains("leche") || texto.contains("gloria") || texto.contains("ideal") ||
                texto.contains("cafe") || texto.contains("altomayo") || texto.contains("nescafe") ||
                texto.contains("avena") || texto.contains("3 ositos") || texto.contains("milo") ||
                texto.contains("yogur") || texto.contains("queso") || texto.contains("mantequilla") ||
                texto.contains("pan ") || texto.contains("panaderia") || texto.contains("desayuno")) {
            return FAM_DESAYUNO;
        }

        if (texto.contains("chocolate") || texto.contains("sublime") || texto.contains("princesa") ||
                texto.contains("picaras") || texto.contains("margarita") || texto.contains("morochas") ||
                texto.contains("chocman") || texto.contains("golosina") || texto.contains("caramelo") ||
                texto.contains("wafer") || texto.contains("dulce") || texto.contains("galleta")) {
            return FAM_GOLOSINAS;
        }

        if (texto.contains("atun") || texto.contains("fideo") || texto.contains("arroz") ||
                texto.contains("tallarin") || texto.contains("spaghetti") || texto.contains("molitalia") ||
                texto.contains("aceite") || texto.contains("primor") || texto.contains("conserva") ||
                texto.contains("salsa") || texto.contains("alacena") || texto.contains("mayonesa") ||
                texto.contains("ketchup") || texto.contains("ajinomen") || texto.contains("menestra") ||
                texto.contains("abarrote") || texto.contains("campomar")) {
            return FAM_ABARROTES;
        }

        return FAM_GENERAL;
    }

    /**
     * Evalúa el puntaje de afinidad y compatibilidad entre dos familias de productos.
     * Retorna un puntaje de 0 a 100:
     * 0 = Estrictamente Incompatible (prohibido combinar)
     * >= 70 = Alta afinidad canasta bodeguera
     */
    public static int evaluarAfinidad(String famA, String famB) {
        if (famA == null || famB == null) return 30;

        // Reglas de exclusión estricta (Puntaje 0)
        if (famA.equals(FAM_MASCOTAS) != famB.equals(FAM_MASCOTAS)) return 0;
        if (famA.equals(FAM_LIMPIEZA) != famB.equals(FAM_LIMPIEZA)) return 0;
        if (famA.equals(FAM_CUIDADO) != famB.equals(FAM_CUIDADO)) return 0;

        // Alcohol nunca con lácteos, desayuno ni abarrotes pesados
        if (famA.equals(FAM_CERVEZAS) || famB.equals(FAM_CERVEZAS)) {
            String otra = famA.equals(FAM_CERVEZAS) ? famB : famA;
            if (otra.equals(FAM_SNACKS)) return 100; // Piqueo y cerveza: 100% afinidad
            if (otra.equals(FAM_BEBIDAS)) return 85; // Mezcladores (gaseosa/jugo): 85%
            if (otra.equals(FAM_CERVEZAS)) return 90; // Pack cervecero
            return 0; // Cerveza con cualquier otra cosa: Incompatible
        }

        // Snacks y Piqueos
        if (famA.equals(FAM_SNACKS) || famB.equals(FAM_SNACKS)) {
            String otra = famA.equals(FAM_SNACKS) ? famB : famA;
            if (otra.equals(FAM_BEBIDAS)) return 100; // Tortees + Gaseosa: 100% afinidad
            if (otra.equals(FAM_SNACKS)) return 85; // Doble snack
            if (otra.equals(FAM_GOLOSINAS)) return 75; // Dulce y salado
            if (otra.equals(FAM_ABARROTES)) return 40;
            return 30;
        }

        // Desayuno y Lácteos
        if (famA.equals(FAM_DESAYUNO) || famB.equals(FAM_DESAYUNO)) {
            String otra = famA.equals(FAM_DESAYUNO) ? famB : famA;
            if (otra.equals(FAM_GOLOSINAS)) return 95; // Leche + Galletas dulces (Pícaras/Margarita)
            if (otra.equals(FAM_DESAYUNO)) return 95; // Leche + Café o Avena
            if (otra.equals(FAM_BEBIDAS)) return 70; // Desayuno con jugo
            if (otra.equals(FAM_ABARROTES)) return 60; // Pan con mermelada / atún desayuno
            return 25;
        }

        // Abarrotes y Cocina
        if (famA.equals(FAM_ABARROTES) || famB.equals(FAM_ABARROTES)) {
            String otra = famA.equals(FAM_ABARROTES) ? famB : famA;
            if (otra.equals(FAM_ABARROTES)) return 100; // Fideos + Atún / Salsa
            if (otra.equals(FAM_BEBIDAS)) return 80; // Menú almuerzo con bebida
            return 30;
        }

        // Bebidas y Golosinas
        if (famA.equals(FAM_BEBIDAS) && famB.equals(FAM_GOLOSINAS) ||
                famA.equals(FAM_GOLOSINAS) && famB.equals(FAM_BEBIDAS)) {
            return 85; // Gaseosa/Agua + Chocolate/Galleta
        }

        // Misma familia no alimentaria
        if (famA.equals(famB)) {
            return 90;
        }

        return 35;
    }

    /**
     * Retorna una etiqueta amigable y estratégica para la afinidad detectada.
     */
    public static String obtenerEtiquetaAfinidad(String famA, String famB) {
        if (famA.equals(FAM_CERVEZAS) || famB.equals(FAM_CERVEZAS)) {
            return "🍻 PIQUEO & BRINDIS";
        }
        if ((famA.equals(FAM_SNACKS) && famB.equals(FAM_BEBIDAS)) || (famB.equals(FAM_SNACKS) && famA.equals(FAM_BEBIDAS))) {
            return "🍿 SNACK & GASEOSA";
        }
        if ((famA.equals(FAM_ABARROTES) && famB.equals(FAM_ABARROTES)) || famA.equals(FAM_ABARROTES) && famB.equals(FAM_BEBIDAS)) {
            return "🥫 ALMUERZO BODEGUERO";
        }
        if (famA.equals(FAM_DESAYUNO) || famB.equals(FAM_DESAYUNO)) {
            return "☕ DESAYUNO & LONCHE";
        }
        if (famA.equals(FAM_LIMPIEZA) && famB.equals(FAM_LIMPIEZA)) {
            return "🧴 PACK LIMPIEZA DEL HOGAR";
        }
        if (famA.equals(FAM_MASCOTAS) && famB.equals(FAM_MASCOTAS)) {
            return "🐾 NUTRICIÓN MASCOTAS";
        }
        if (famA.equals(FAM_CUIDADO) && famB.equals(FAM_CUIDADO)) {
            return "✨ CUIDADO PERSONAL";
        }
        return "⭐ COMBO DUO AFÍN";
    }
}
