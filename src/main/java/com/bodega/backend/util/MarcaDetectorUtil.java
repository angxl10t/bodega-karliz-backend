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
        register("Inca Kola", "\\b(inka|inca)\\s*kola\\b");
        register("Coca-Cola", "\\bcoca\\s*[- ]?cola\\b");
        register("Pepsi", "\\bpepsi(\\s*black)?\\b");
        register("7Up", "\\b7\\s*up\\b");
        register("Concordia", "\\bconcordia\\b");
        register("Kola Real", "\\bkola\\s*real\\b");
        register("Fanta", "\\bfanta\\b");
        register("Sprite", "\\bsprite\\b");
        register("San Mateo", "\\bsan\\s*mateo\\b");
        register("San Luis", "\\bsan\\s*luis\\b");
        register("Cielo", "\\bagua\\s*cielo\\b|\\bcielo\\b");
        register("Sporade", "\\bsporade\\b");
        register("Gatorade", "\\bgatorade\\b");
        register("Volt", "\\bvolt\\b");
        register("Monster", "\\bmonster(\\s*energy)?\\b");
        register("Red Bull", "\\bred\\s*bull\\b");
        register("Frugos", "\\bfrugos(\\s*del\\s*valle)?\\b");
        register("Pulp", "\\bpulp\\b");
        register("Tampico", "\\btampico\\b");
        register("Cifrut", "\\bcifrut\\b");
        register("Free Tea", "\\bfree\\s*tea\\b");

        // Cervezas y Licores
        register("Pilsen Callao", "\\bpilsen(\\s*callao)?\\b");
        register("Cristal", "\\b(cerveza\\s*)?cristal\\b");
        register("Cusqueña", "\\bcusqueña|cusquena\\b");
        register("Corona", "\\b(cerveza\\s*)?corona\\b");
        register("Stella Artois", "\\bstella(\\s*artois)?\\b");
        register("Heineken", "\\bheineken\\b");
        register("Budweiser", "\\bbudweiser\\b");
        register("Cartavio", "\\bcartavio\\b");
        register("Santiago Queirolo", "\\b(santiago\\s*)?queirolo\\b");
        register("Tabernero", "\\btabernero\\b");
        register("Tacama", "\\btacama\\b");
        register("Johnnie Walker", "\\bjohnnie\\s*walker\\b");
        register("Four Loko", "\\bfour\\s*loko\\b");
        register("Russkaya", "\\brusskaya\\b");
        register("Smirnoff", "\\bsmirnoff\\b");

        // Lácteos y Desayuno
        register("Gloria", "\\bgloria\\b");
        register("Laive", "\\blaive\\b");
        register("Ideal", "\\bideal(\\s*(cremosita|amanecer))?\\b");
        register("Pura Vida", "\\bpura\\s*vida\\b");
        register("Nestlé", "\\bnestl[eé]\\b");
        register("Milo", "\\bmilo\\b");
        register("Nescafé", "\\bnescaf[eé]\\b");
        register("Altomayo", "\\baltomayo\\b");
        register("Cafetal", "\\bcafetal\\b");
        register("Kirma", "\\bkirma\\b");
        register("McColin's", "\\bmccolins?|mc\\s*colins?\\b");
        register("Herbi", "\\bherbi\\b");
        register("Bimbo", "\\bbimbo\\b");
        register("Quaker", "\\bquaker\\b");
        register("3 Ositos", "\\b3\\s*ositos|tres\\s*ositos\\b");
        register("Ángel", "\\b[aá]ngel\\b");
        register("Todinno", "\\btodinno\\b");
        register("Motta", "\\bmotta\\b");
        register("Winter's", "\\bwinter'?s?\\b");
        register("Blanca Flor", "\\bblanca\\s*flor\\b");

        // Snacks y Piqueos
        register("Lay's", "\\blay'?s\\b");
        register("Doritos", "\\bdoritos\\b");
        register("Cheetos", "\\bcheetos\\b");
        register("Cheese Tris", "\\bcheese\\s*tris\\b");
        register("Cuates", "\\bcuates\\b");
        register("Karinto", "\\bkarinto\\b");
        register("Piqueo Snax", "\\bpiqueo\\s*snax\\b");
        register("Tortees", "\\btortees\\b");
        register("Chizitos", "\\bchizitos?\\b");
        register("Frito-Lay", "\\bfrito\\s*[- ]?lay\\b");
        register("Pringles", "\\bpringles\\b");

        // Golosinas, Galletas y Chocolates
        register("D'Onofrio", "\\bd'?onofrio\\b");
        register("Sublime", "\\bsublime\\b");
        register("Triángulo", "\\btri[aá]ngulo\\b");
        register("Princesa", "\\bprincesa\\b");
        register("Cua Cua", "\\bcua\\s*[- ]?cua\\b");
        register("Doña Pepa", "\\bdo[ñn]a\\s*pepa\\b");
        register("Morochas", "\\bmorochas\\b");
        register("Casino", "\\bcasino\\b");
        register("Tentación", "\\btentaci[oó]n\\b");
        register("Rellenitas", "\\brellenitas?\\b");
        register("Margarita", "\\bmargarita\\b");
        register("Charada", "\\bcharada\\b");
        register("Glacitas", "\\bglacitas\\b");
        register("San Jorge", "\\bsan\\s*jorge\\b");
        register("Costa", "\\bcosta\\b");
        register("Field", "\\bfield\\b");
        register("Ambrosoli", "\\bambrosoli\\b");
        register("Halls", "\\bhalls\\b");
        register("Trident", "\\btrident\\b");
        register("Frunas", "\\bfrunas?\\b");

        // Abarrotes y Despensa
        register("Costeño", "\\bcoste[ñn]o\\b");
        register("Paisana", "\\bpaisana\\b");
        register("Molitalia", "\\bmolitalia\\b");
        register("Don Vittorio", "\\bdon\\s*vittorio\\b");
        register("Lavaggi", "\\blavaggi\\b");
        register("Nicolini", "\\bnicolini\\b");
        register("Anita", "\\banita\\b");
        register("Primor", "\\bprimor\\b");
        register("Cil", "\\baceite\\s*cil\\b|\\bcil\\b");
        register("Capri", "\\bcapri\\b");
        register("AlaCena", "\\bala\\s*cena|alacena\\b");
        register("Florida", "\\bflorida\\b");
        register("Campomar", "\\bcampomar\\b");
        register("Fanny", "\\bfanny\\b");
        register("Compass", "\\bcompass\\b");
        register("Ajinomoto", "\\bajinomoto\\b");
        register("Doña Gusta", "\\bdo[ñn]a\\s*gusta\\b");
        register("Sibarita", "\\bsibarita\\b");

        // Limpieza y Cuidado del Hogar
        register("Ariel", "\\bariel\\b");
        register("Ace", "\\bace\\b");
        register("Bolívar", "\\bbol[ií]var\\b");
        register("Opal", "\\bopal\\b");
        register("Clorox", "\\bclorox\\b");
        register("Sapolio", "\\bsapolio\\b");
        register("Ayudín", "\\bayud[ií]n\\b");
        register("Poett", "\\bpoett\\b");
        register("Elite", "\\belite\\b");
        register("Paracas", "\\bparacas\\b");
        register("Suave", "\\b(papel\\s*)?suave\\b");
        register("Noble", "\\bnoble\\b");

        // Cuidado Personal
        register("Colgate", "\\bcolgate\\b");
        register("Dento", "\\bdento\\b");
        register("Kolynos", "\\bkolynos\\b");
        register("Head & Shoulders", "\\bhead\\s*(&|and)?\\s*shoulders|h&s\\b");
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
        register("Marlboro", "\\bmarl?boro\\b");
        register("Hamilton", "\\bhamilton\\b");
        register("Pall Mall", "\\bpall\\s*mall\\b");
        register("Tokai", "\\btokai\\b");
        register("La Llama", "\\bla\\s*llama\\b");
    }

    private static void register(String canonical, String regex) {
        BRAND_RULES.add(new BrandRule(canonical, regex));
        NORMALIZATION_MAP.put(canonical.toLowerCase(), canonical);
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
