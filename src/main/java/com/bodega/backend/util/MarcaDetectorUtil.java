package com.bodega.backend.util;

import java.util.*;
import java.util.regex.Pattern;

/**
 * Utilidad inteligente para detección y normalización automática de marcas
 * de productos de consumo masivo para bodegas y minimarkets peruanos.
 */
public final class MarcaDetectorUtil {

    private MarcaDetectorUtil() {}

    // Lista canónica ordenada de marcas peruanas (marcas más específicas o compuestas primero)
    private static final List<BrandRule> BRAND_RULES = new ArrayList<>();
    private static final Map<String, String> NORMALIZATION_MAP = new TreeMap<>(String.CASE_INSENSITIVE_ORDER);

    private static class BrandRule {
        final String canonicalName;
        final Pattern pattern;

        BrandRule(String canonicalName, String regex) {
            this.canonicalName = canonicalName;
            this.pattern = Pattern.compile(regex, Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE);
        }
    }

    static {
        // Bebidas y Gaseosas
        register("Inca Kola", "\\b(inka|inca)\\s*[- ]?kola\\b", "Inka Kola", "Inca-Kola", "Inka-Kola");
        register("Coca-Cola", "\\bcoca\\s*[- ]?cola\\b", "Coca Cola", "CocaCola", "Coke");
        register("Pepsi", "\\bpepsi(\\s*black)?\\b", "Pepsi Black");
        register("7Up", "\\b7\\s*[- ]?up\\b|\\bseven\\s*[- ]?up\\b", "7 Up", "7-Up", "Seven Up");
        register("Concordia", "\\bconcordia\\b");
        register("Kola Real", "\\bkola\\s*[- ]?real\\b|\\bkr\\b", "KR", "KR Cola");
        register("Fanta", "\\bfanta\\b");
        register("Sprite", "\\bsprite\\b");
        register("San Mateo", "\\bsan\\s*[- ]?mateo\\b", "San-Mateo");
        register("San Luis", "\\bsan\\s*[- ]?luis\\b", "San-Luis");
        register("Cielo", "\\bagua\\s*cielo\\b|\\bcielo\\b");
        register("Sporade", "\\bsporade\\b");
        register("Gatorade", "\\bgatorade\\b");
        register("Volt", "\\bvolt\\b");
        register("Monster", "\\bmonster(\\s*energy)?\\b", "Monster Energy");
        register("Red Bull", "\\bred\\s*[- ]?bull\\b", "Red-Bull");
        register("Frugos", "\\bfrugos(\\s*del\\s*valle)?\\b", "Frugos del Valle");
        register("Pulp", "\\bpulp\\b");
        register("Tampico", "\\btampico\\b");
        register("Cifrut", "\\bcifrut\\b");
        register("Free Tea", "\\bfree\\s*[- ]?tea\\b", "Free-Tea");

        // Cervezas y Licores
        register("Pilsen Callao", "\\bpilsen(\\s*callao)?\\b", "Pilsen");
        register("Cristal", "\\b(cerveza\\s*)?cristal\\b", "Cerveza Cristal");
        register("Cusqueña", "\\bcusqueña|cusquena\\b", "Cusquena");
        register("Corona", "\\b(cerveza\\s*)?corona\\b", "Cerveza Corona");
        register("Stella Artois", "\\bstella(\\s*artois)?\\b");
        register("Heineken", "\\bheineken\\b");
        register("Budweiser", "\\bbudweiser\\b");
        register("Cartavio", "\\bcartavio\\b");
        register("Santiago Queirolo", "\\b(santiago\\s*)?queirolo\\b", "Queirolo");
        register("Tabernero", "\\btabernero\\b");
        register("Tacama", "\\btacama\\b");
        register("Johnnie Walker", "\\bjohnnie\\s*[- ]?walker\\b");
        register("Four Loko", "\\bfour\\s*[- ]?loko\\b");
        register("Russkaya", "\\brusskaya\\b");
        register("Smirnoff", "\\bsmirnoff\\b");

        // Lácteos y Desayuno
        register("Gloria", "\\bgloria\\b");
        register("Laive", "\\blaive\\b");
        register("Ideal", "\\bideal(\\s*(cremosita|amanecer))?\\b");
        register("Pura Vida", "\\bpura\\s*[- ]?vida\\b");
        register("Nestlé", "\\bnestl[eé]\\b", "Nestle");
        register("Milo", "\\bmilo\\b");
        register("Nescafé", "\\bnescaf[eé]\\b", "Nescafe");
        register("Altomayo", "\\baltomayo\\b");
        register("Cafetal", "\\bcafetal\\b");
        register("Kirma", "\\bkirma\\b");
        register("McColin's", "\\bmccolins?|mc\\s*colins?\\b", "Mccolins", "Mc Colins");
        register("Herbi", "\\bherbi\\b");
        register("Bimbo", "\\bbimbo\\b");
        register("Quaker", "\\bquaker\\b");
        register("3 Ositos", "\\b3\\s*[- ]?ositos|tres\\s*[- ]?ositos\\b", "Tres Ositos");
        register("Ángel", "\\b[aá]ngel\\b", "Angel");
        register("Todinno", "\\btodinno\\b");
        register("Motta", "\\bmotta\\b");
        register("Winter's", "\\bwinter'?s?\\b", "Winters");
        register("Blanca Flor", "\\bblanca\\s*[- ]?flor\\b", "Blancaflor");

        // Snacks y Piqueos
        register("Lay's", "\\blay'?s\\b", "Lays", "Lay s");
        register("Doritos", "\\bdoritos\\b");
        register("Cheetos", "\\bcheetos\\b");
        register("Cheese Tris", "\\bcheese\\s*[- ]?tris\\b");
        register("Cuates", "\\bcuates\\b");
        register("Karinto", "\\bkarinto\\b");
        register("Piqueo Snax", "\\bpiqueo\\s*[- ]?snax\\b");
        register("Tortees", "\\btortees\\b");
        register("Chizitos", "\\bchizitos?\\b");
        register("Frito-Lay", "\\bfrito\\s*[- ]?lay\\b", "Frito Lay");
        register("Pringles", "\\bpringles\\b");

        // Golosinas, Galletas y Chocolates
        register("D'Onofrio", "\\bd'?onofrio\\b", "Donofrio", "D onofrio");
        register("Sublime", "\\bsublime\\b");
        register("Triángulo", "\\btri[aá]ngulo\\b", "Triangulo");
        register("Princesa", "\\bprincesa\\b");
        register("Cua Cua", "\\bcua\\s*[- ]?cua\\b");
        register("Doña Pepa", "\\bdo[ñn]a\\s*[- ]?pepa\\b", "Dona Pepa");
        register("Morochas", "\\bmorochas\\b");
        register("Casino", "\\bcasino\\b");
        register("Tentación", "\\btentaci[oó]n\\b", "Tentacion");
        register("Rellenitas", "\\brellenitas?\\b");
        register("Margarita", "\\bmargarita\\b");
        register("Charada", "\\bcharada\\b");
        register("Glacitas", "\\bglacitas\\b");
        register("San Jorge", "\\bsan\\s*[- ]?jorge\\b");
        register("Costa", "\\bcosta\\b");
        register("Field", "\\bfield\\b");
        register("Ambrosoli", "\\bambrosoli\\b");
        register("Halls", "\\bhalls\\b");
        register("Trident", "\\btrident\\b");
        register("Frunas", "\\bfrunas?\\b");

        // Abarrotes y Despensa
        register("Costeño", "\\bcoste[ñn]o\\b", "Costeno");
        register("Paisana", "\\bpaisana\\b");
        register("Molitalia", "\\bmolitalia\\b");
        register("Don Vittorio", "\\bdon\\s*[- ]?vittorio\\b");
        register("Lavaggi", "\\blavaggi\\b");
        register("Nicolini", "\\bnicolini\\b");
        register("Anita", "\\banita\\b");
        register("Primor", "\\bprimor\\b");
        register("Cil", "\\baceite\\s*cil\\b|\\bcil\\b");
        register("Capri", "\\bcapri\\b");
        register("AlaCena", "\\bala\\s*cena|alacena\\b", "Alacena", "Ala Cena");
        register("Florida", "\\bflorida\\b");
        register("Campomar", "\\bcampomar\\b");
        register("Fanny", "\\bfanny\\b");
        register("Compass", "\\bcompass\\b");
        register("Ajinomoto", "\\bajinomoto\\b");
        register("Doña Gusta", "\\bdo[ñn]a\\s*[- ]?gusta\\b", "Dona Gusta");
        register("Sibarita", "\\bsibarita\\b");

        // Limpieza y Cuidado del Hogar
        register("Ariel", "\\bariel\\b");
        register("Ace", "\\bace\\b");
        register("Bolívar", "\\bbol[ií]var\\b", "Bolivar");
        register("Opal", "\\bopal\\b");
        register("Clorox", "\\bclorox\\b");
        register("Sapolio", "\\bsapolio\\b");
        register("Ayudín", "\\bayud[ií]n\\b", "Ayudin");
        register("Poett", "\\bpoett\\b");
        register("Elite", "\\belite\\b");
        register("Paracas", "\\bparacas\\b");
        register("Suave", "\\b(papel\\s*)?suave\\b");
        register("Noble", "\\bnoble\\b");

        // Cuidado Personal
        register("Colgate", "\\bcolgate\\b");
        register("Dento", "\\bdento\\b");
        register("Kolynos", "\\bkolynos\\b");
        register("Head & Shoulders", "\\bhead\\s*(&|and)?\\s*shoulders|h&s\\b", "H&S", "Head and Shoulders");
        register("Pantene", "\\bpantene\\b");
        register("Sedal", "\\bsedal\\b");
        register("Dove", "\\bdove\\b");
        register("Rexona", "\\brexona\\b");
        register("Nivea", "\\bnivea\\b");
        register("Gillette", "\\bgillette\\b");
        register("Huggies", "\\bhuggies\\b");
        register("Babysec", "\\bbabysec\\b");

        // Cigarrillos y Fósforos
        register("Lucky Strike", "\\blucky(\\s*strike)?\\b");
        register("Marlboro", "\\b(marlboro|malboro)\\b", "Malboro");
        register("Hamilton", "\\bhamilton\\b");
        register("Pall Mall", "\\bpall\\s*[- ]?mall\\b");
        register("Tokai", "\\btokai\\b");
        register("La Llama", "\\bla\\s*[- ]?llama\\b");
    }

    private static void register(String canonical, String regex, String... aliases) {
        BrandRule rule = new BrandRule(canonical, regex);
        BRAND_RULES.add(rule);
        NORMALIZATION_MAP.put(canonical.toLowerCase(), canonical);
        NORMALIZATION_MAP.put(simplificar(canonical), canonical);
        if (aliases != null) {
            for (String alias : aliases) {
                if (alias != null && !alias.isBlank()) {
                    NORMALIZATION_MAP.put(alias.toLowerCase(), canonical);
                    NORMALIZATION_MAP.put(simplificar(alias), canonical);
                }
            }
        }
    }

    /**
     * Simplifica un texto para comparación tolerante a variantes:
     * convierte a minúsculas, remueve acentos/diacríticos y elimina puntuación, guiones y espacios.
     * Ejemplo: "Coca-Cola" -> "cocacola", "Lay's" -> "lays", "D'Onofrio" -> "donofrio", "Ángel" -> "angel".
     */
    public static String simplificar(String s) {
        if (s == null || s.isBlank()) return "";
        String nfd = java.text.Normalizer.normalize(s.toLowerCase(), java.text.Normalizer.Form.NFD);
        String noAccents = nfd.replaceAll("\\p{M}", "");
        return noAccents.replaceAll("[^a-z0-9]", "");
    }

    /**
     * Localiza la regla canónica BrandRule que coincida con el nombre o alias dado.
     */
    private static BrandRule findRule(String brandName) {
        if (brandName == null || brandName.isBlank()) return null;
        final String simp = simplificar(brandName);
        for (BrandRule rule : BRAND_RULES) {
            if (rule.canonicalName.equalsIgnoreCase(brandName) ||
                simplificar(rule.canonicalName).equalsIgnoreCase(simp) ||
                rule.pattern.matcher(brandName).find()) {
                return rule;
            }
        }
        return null;
    }

    /**
     * Determina con precisión exhaustiva y tolerancia total a variantes si un producto
     * pertenece a la marca objetivo de una promoción.
     * Evalúa la marca asignada al producto, su nombre, y las reglas canónicas regex.
     */
    public static boolean coincideMarca(String marcaObjetivo, String marcaProducto, String nombreProducto) {
        if (marcaObjetivo == null || marcaObjetivo.isBlank()) {
            return false;
        }

        final String targetTrim = marcaObjetivo.trim();
        final String canonicalTarget = normalizarMarca(targetTrim);
        final String simpTarget = simplificar(targetTrim);
        final String simpCanonical = simplificar(canonicalTarget != null ? canonicalTarget : targetTrim);

        // 1. Coincidencia por BrandRule canónica (Regex compilada oficial)
        BrandRule targetRule = findRule(canonicalTarget != null ? canonicalTarget : targetTrim);
        if (targetRule != null) {
            if (marcaProducto != null && !marcaProducto.isBlank() && targetRule.pattern.matcher(marcaProducto).find()) {
                return true;
            }
            if (nombreProducto != null && !nombreProducto.isBlank() && targetRule.pattern.matcher(nombreProducto).find()) {
                return true;
            }
        }

        // 2. Coincidencia directa contra marcaProducto (normalizada o simplificada)
        if (marcaProducto != null && !marcaProducto.isBlank()) {
            final String prodMarcaTrim = marcaProducto.trim();
            if (prodMarcaTrim.equalsIgnoreCase(targetTrim)) {
                return true;
            }
            final String canonicalProd = normalizarMarca(prodMarcaTrim);
            if (canonicalTarget != null && canonicalTarget.equalsIgnoreCase(canonicalProd)) {
                return true;
            }
            final String simpProd = simplificar(prodMarcaTrim);
            if (simpTarget.equals(simpProd) || simpCanonical.equals(simpProd)) {
                return true;
            }
            if (simpProd.contains(simpTarget) || (simpTarget.length() >= 4 && simpTarget.contains(simpProd))) {
                return true;
            }
        }

        // 3. Coincidencia en nombreProducto (marca detectada o subcadena simplificada)
        if (nombreProducto != null && !nombreProducto.isBlank()) {
            final String detectedInName = detectarMarca(nombreProducto);
            if (detectedInName != null) {
                if (detectedInName.equalsIgnoreCase(canonicalTarget != null ? canonicalTarget : targetTrim)) {
                    return true;
                }
                if (simplificar(detectedInName).equals(simpCanonical)) {
                    return true;
                }
            }
            final String simpName = simplificar(nombreProducto);
            if (simpTarget.length() >= 3 && simpName.contains(simpTarget)) {
                return true;
            }
            if (simpCanonical.length() >= 3 && simpName.contains(simpCanonical)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Detecta automáticamente la marca a partir del nombre del producto.
     * Retorna la marca en formato canónico oficial o null si no se identifica.
     */
    public static String detectarMarca(String nombreProducto) {
        if (nombreProducto == null || nombreProducto.isBlank()) {
            return null;
        }
        String clean = nombreProducto.trim();
        for (BrandRule rule : BRAND_RULES) {
            if (rule.pattern.matcher(clean).find()) {
                return rule.canonicalName;
            }
        }
        return null;
    }

    /**
     * Normaliza el formato de una marca dada (ej. "alacena" -> "AlaCena", "pepsi" -> "Pepsi").
     * Si no coincide con ninguna conocida, retorna el string con mayúscula inicial limpia.
     */
    public static String normalizarMarca(String marca) {
        if (marca == null || marca.isBlank()) {
            return null;
        }
        String trimmed = marca.trim();
        // 1. Verificar coincidencia en diccionario directo
        String canonical = NORMALIZATION_MAP.get(trimmed.toLowerCase());
        if (canonical != null) {
            return canonical;
        }
        // 2. Si es un alias o variante conocida (ej. "lays" -> "Lay's", "donofrio" -> "D'Onofrio")
        String detected = detectarMarca(trimmed);
        if (detected != null) {
            return detected;
        }
        // 3. Fallback: mayúscula inicial por palabra
        String[] parts = trimmed.split("\\s+");
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < parts.length; i++) {
            if (!parts[i].isEmpty()) {
                if (i > 0) sb.append(" ");
                sb.append(Character.toUpperCase(parts[i].charAt(0)));
                if (parts[i].length() > 1) {
                    sb.append(parts[i].substring(1).toLowerCase());
                }
            }
        }
        return sb.toString();
    }
}
