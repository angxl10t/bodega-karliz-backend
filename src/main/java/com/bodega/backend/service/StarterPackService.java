package com.bodega.backend.service;

import com.bodega.backend.dto.StarterPackPresetDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Categoria;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.entity.StarterPackPreset;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.StarterPackPresetRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.*;

@Service
public class StarterPackService {

    private static final Logger log = LoggerFactory.getLogger(StarterPackService.class);

    private final JdbcTemplate jdbcTemplate;
    private final BodegaRepository bodegaRepository;
    private final CategoriaRepository categoriaRepository;
    private final ProductoRepository productoRepository;
    private final StarterPackPresetRepository starterPackPresetRepository;

    public StarterPackService(JdbcTemplate jdbcTemplate,
                              BodegaRepository bodegaRepository,
                              CategoriaRepository categoriaRepository,
                              ProductoRepository productoRepository,
                              StarterPackPresetRepository starterPackPresetRepository) {
        this.jdbcTemplate = jdbcTemplate;
        this.bodegaRepository = bodegaRepository;
        this.categoriaRepository = categoriaRepository;
        this.productoRepository = productoRepository;
        this.starterPackPresetRepository = starterPackPresetRepository;
    }

    public static final String[][] CATEGORIAS_CANONICAS = {
        {"Gaseosas y Bebidas", "Gaseosas, aguas minerales, jugos, néctares, energizantes e hidratantes"},
        {"Bebidas Alcohólicas", "Cervezas, piscos, rones, vinos y licores"},
        {"Snacks y Piqueos", "Papas fritas, chizitos, tortillas, platanitos y frutos secos"},
        {"Lácteos y Derivados", "Leche evaporada, fresca, yogures, mantequillas, quesos y huevos"},
        {"Abarrotes y Despensa", "Arroz, azúcar, fideos, aceites, conservas y condimentos"},
        {"Golosinas y Chocolates", "Chocolates, galletas dulces, caramelos y confitería"},
        {"Embutidos y Fiambrería", "Hot dogs, jamonadas, salchichas, tocinos y embutidos"},
        {"Panadería y Desayuno", "Pan de molde, mermeladas, café, avena e infusiones"},
        {"Limpieza y Cuidado del Hogar", "Detergentes, lejías, lavavajillas, suavizantes y esponjas"},
        {"Cuidado Personal y Dental", "Cremas dentales, jabones, champús y papel higiénico"},
        {"Helados y Congelados", "Helados en paleta, conos, bombones y potes familiares"},
        {"Cigarrillos y Tabaco", "Cigarrillos en cajetilla, fósforos y encendedores"}
    };

    /**
     * Catálogo comercial expandido de productos de alta rotación para bodegas peruanas.
     * Formato: {Código de barras EAN-13, Nombre completo comercial, Marca, Categoría Canónica, Precio Venta Ref, Precio Costo Ref, Imagen URL}
     */
    public static final String[][] PRODUCTOS_STARTER_PACK = {
        // --- 1. GASEOSAS Y BEBIDAS ---
        {"7750106001010", "Inca Kola Sabor Original 500ml", "Inca Kola", "Gaseosas y Bebidas", "3.00", "2.30", "packshots/inka_kola_500ml.png"},
        {"7750106001027", "Inca Kola Sabor Original 1.5 Litros", "Inca Kola", "Gaseosas y Bebidas", "6.50", "5.20", "packshots/inka_kola.png"},
        {"7750106000013", "Inca Kola Sabor Original 3 Litros", "Inca Kola", "Gaseosas y Bebidas", "12.00", "9.80", "packshots/inka_kola_3l.png"},
        {"7750106001034", "Inca Kola Sin Azúcar Zero 500ml", "Inca Kola", "Gaseosas y Bebidas", "3.00", "2.30", "packshots/inka_kola_500ml.png"},
        {"7750106000025", "Coca Cola Sabor Original 500ml", "Coca Cola", "Gaseosas y Bebidas", "3.00", "2.30", "packshots/coca_cola_500ml.png"},
        {"7750106002017", "Coca Cola Sabor Original 1.5 Litros", "Coca Cola", "Gaseosas y Bebidas", "6.50", "5.20", "packshots/coca_cola.png"},
        {"7751234567890", "Coca Cola Sabor Original 3 Litros", "Coca Cola", "Gaseosas y Bebidas", "12.00", "9.80", "packshots/coca_cola_3l.png"},
        {"7750106000032", "Coca Cola Sin Azúcar Zero 500ml", "Coca Cola", "Gaseosas y Bebidas", "3.00", "2.30", "packshots/coca_cola_500ml.png"},
        {"7750182220378", "Gaseosa Fanta Naranja 500ml", "Fanta", "Gaseosas y Bebidas", "2.50", "1.90", "packshots/fanta_500ml.png"},
        {"7750182495301", "Gaseosa Fanta Naranja 3 Litros", "Fanta", "Gaseosas y Bebidas", "10.50", "8.40", "packshots/fanta_3l.png"},
        {"7750182000321", "Gaseosa Sprite Lima Limón 500ml", "Sprite", "Gaseosas y Bebidas", "2.50", "1.90", "packshots/sprite_500ml.png"},
        {"7750182000222", "Gaseosa Sprite Lima Limón 3 Litros", "Sprite", "Gaseosas y Bebidas", "10.50", "8.40", "packshots/sprite_3l.png"},
        {"7753749003186", "Gaseosa Guaraná Backus 450ml", "Backus", "Gaseosas y Bebidas", "2.20", "1.70", "packshots/guarana_450ml.png"},
        {"7753749003193", "Gaseosa Guaraná Backus 3 Litros", "Backus", "Gaseosas y Bebidas", "9.50", "7.60", "packshots/guarana.png"},
        {"7750106003014", "Agua San Luis 625ml Sin Gas", "San Luis", "Gaseosas y Bebidas", "1.50", "1.10", "packshots/agua_san_luis.png"},
        {"7750106003021", "Agua San Luis Sin Gas Bidón 7 Litros", "San Luis", "Gaseosas y Bebidas", "7.50", "5.80", "packshots/agua_san_luis.png"},
        {"775117011953", "Agua Mineral San Mateo 600ml Sin Gas", "San Mateo", "Gaseosas y Bebidas", "1.50", "1.10", "packshots/agua_san_mateo.png"},
        {"7750670010238", "Bebida Rehidratante Sporade Tropical 625ml", "Sporade", "Gaseosas y Bebidas", "2.20", "1.70", "packshots/sporade.png"},
        {"7750670010245", "Bebida Rehidratante Sporade Maracuyá 625ml", "Sporade", "Gaseosas y Bebidas", "2.20", "1.70", "packshots/sporade.png"},
        {"7750670010412", "Bebida de Frutas Cifrut Citrus Punch 3 Litros", "Cifrut", "Gaseosas y Bebidas", "6.00", "4.80", "packshots/cifrut.png"},
        {"7750670010429", "Bebida de Frutas Cifrut Citrus Punch 500ml", "Cifrut", "Gaseosas y Bebidas", "1.50", "1.10", "packshots/cifrut.png"},
        {"90162602", "Bebida Energizante Red Bull Lata 355ml", "Red Bull", "Gaseosas y Bebidas", "8.50", "6.80", "packshots/red_bull.png"},
        {"7750182000406", "Gaseosa Pepsi Sabor Original 500ml", "Pepsi", "Gaseosas y Bebidas", "2.20", "1.70", "packshots/pepsi_500ml.png"},
        {"7750182000413", "Gaseosa Pepsi Sabor Original 1.5 Litros", "Pepsi", "Gaseosas y Bebidas", "5.50", "4.30", "packshots/pepsi.png"},
        {"7750182000420", "Gaseosa Pepsi Sabor Original 3 Litros", "Pepsi", "Gaseosas y Bebidas", "9.00", "7.20", "packshots/pepsi_3l.png"},
        {"7750182000437", "Gaseosa 7Up Lima Limón 500ml", "7Up", "Gaseosas y Bebidas", "2.20", "1.70", "packshots/seven_up.png"},
        {"7750182000444", "Gaseosa 7Up Lima Limón 3 Litros", "7Up", "Gaseosas y Bebidas", "9.00", "7.20", "packshots/seven_up.png"},
        {"7750182000451", "Gaseosa Concordia Piña 500ml", "Concordia", "Gaseosas y Bebidas", "1.80", "1.30", "packshots/concordia_pina.png"},
        {"7750182000468", "Gaseosa Concordia Piña 3 Litros", "Concordia", "Gaseosas y Bebidas", "7.00", "5.50", "packshots/concordia_pina.png"},
        {"7750670010115", "Gaseosa Kola Real KR Cola Negra 3 Litros", "Kola Real", "Gaseosas y Bebidas", "6.00", "4.70", "packshots/kr_cola.png"},
        {"7750670010122", "Gaseosa Kola Real KR Piña 3 Litros", "Kola Real", "Gaseosas y Bebidas", "6.00", "4.70", "packshots/kr_pina.png"},
        {"7753749003209", "Gaseosa Guaraná Backus Lata 355ml", "Backus", "Gaseosas y Bebidas", "2.50", "1.90", "packshots/guarana_450ml.png"},
        {"7753749003216", "Gaseosa Guaraná Backus 1.5 Litros", "Backus", "Gaseosas y Bebidas", "5.80", "4.60", "packshots/guarana.png"},
        {"7750106000049", "Gaseosa Canada Dry Ginger Ale 1.5L", "Canada Dry", "Gaseosas y Bebidas", "5.80", "4.50", "packshots/canada_dry.png"},
        {"70847811169", "Bebida Energizante Monster Energy 473ml", "Monster Energy", "Gaseosas y Bebidas", "7.50", "5.80", "packshots/monster_energy.png"},
        {"70847022909", "Bebida Energizante Monster Ultra White 473ml", "Monster Energy", "Gaseosas y Bebidas", "7.50", "5.80", "packshots/monster_energy_ultra.png"},
        {"7750670010511", "Bebida Energizante Volt Blue Energy 300ml", "Volt", "Gaseosas y Bebidas", "2.00", "1.50", "packshots/volt_blue.png"},
        {"7750670010528", "Bebida Energizante Volt Maca 300ml", "Volt", "Gaseosas y Bebidas", "2.00", "1.50", "packshots/volt_maca.png"},
        {"7750670010535", "Bebida Energizante Volt Ginseng 300ml", "Volt", "Gaseosas y Bebidas", "2.00", "1.50", "packshots/volt_ginseng.png"},
        {"7750106008019", "Jugo Frugos del Valle Durazno 1 Litro", "Frugos", "Gaseosas y Bebidas", "3.80", "2.90", "packshots/frugos_durazno.png"},
        {"7750106008033", "Jugo Frugos del Valle Mango 1 Litro", "Frugos", "Gaseosas y Bebidas", "3.80", "2.90", "packshots/frugos_mango.png"},
        {"7750106008040", "Jugo Frugos del Valle Naranja 1 Litro", "Frugos", "Gaseosas y Bebidas", "3.80", "2.90", "packshots/frugos_naranja.png"},
        {"7750670010320", "Néctar Pulp Durazno Botella 300ml", "Pulp", "Gaseosas y Bebidas", "1.80", "1.30", "packshots/pulp_durazno.png"},
        {"7750670010313", "Néctar Pulp Durazno Caja 1 Litro", "Pulp", "Gaseosas y Bebidas", "3.50", "2.70", "packshots/pulp_durazno.png"},
        {"7750800001012", "Bebida de Frutas Tampico Citrus 1 Litro", "Tampico", "Gaseosas y Bebidas", "2.80", "2.10", "packshots/tampico.png"},
        {"7750800001029", "Bebida de Frutas Tampico Citrus 3 Litros", "Tampico", "Gaseosas y Bebidas", "6.50", "5.00", "packshots/tampico_3l.png"},
        {"7750670010016", "Agua Cielo Sin Gas 625ml", "Cielo", "Gaseosas y Bebidas", "1.20", "0.80", "packshots/agua_cielo.png"},
        {"7750670010030", "Agua Cielo Sin Gas Bidón 7 Litros", "Cielo", "Gaseosas y Bebidas", "6.50", "5.00", "packshots/agua_cielo_7l.png"},
        {"7750182000604", "Bebida Rehidratante Gatorade Cool Blue 500ml", "Gatorade", "Gaseosas y Bebidas", "2.80", "2.10", "packshots/gatorade_cool_blue.png"},
        {"7750182000611", "Bebida Rehidratante Gatorade Tropical 500ml", "Gatorade", "Gaseosas y Bebidas", "2.80", "2.10", "packshots/gatorade_tropical.png"},

        // --- 2. BEBIDAS ALCOHÓLICAS Y LICORES ---
        {"7750111006014", "Cerveza Pilsen Callao 630ml Retornable", "Pilsen Callao", "Bebidas Alcohólicas", "6.50", "5.20", "packshots/cerveza_pilsen.png"},
        {"7750111006038", "Cerveza Pilsen Callao 355ml Lata", "Pilsen Callao", "Bebidas Alcohólicas", "4.20", "3.30", "packshots/cerveza_pilsen.png"},
        {"7750111006021", "Cerveza Cristal 650ml Retornable", "Cristal", "Bebidas Alcohólicas", "6.50", "5.10", "packshots/cerveza_cristal.png"},
        {"7750111006045", "Cerveza Cristal 355ml Lata", "Cristal", "Bebidas Alcohólicas", "4.20", "3.30", "packshots/cerveza_cristal_lata.png"},
        {"7750106006022", "Cerveza Cusqueña Dorada 310ml", "Cusqueña", "Bebidas Alcohólicas", "5.50", "4.30", "packshots/cerveza_cusquena_dorada.png"},
        {"7750106006015", "Cerveza Cusqueña Trigo 310ml", "Cusqueña", "Bebidas Alcohólicas", "5.50", "4.30", "packshots/cerveza_cusquena.png"},
        {"750106419166", "Cerveza Corona Extra Botella 355ml", "Corona", "Bebidas Alcohólicas", "6.50", "5.00", "packshots/cerveza_corona.png"},
        {"7891991000826", "Cerveza Stella Artois Botella 330ml", "Stella Artois", "Bebidas Alcohólicas", "7.00", "5.40", "packshots/cerveza_stella.png"},
        {"7750174000018", "Pisco Queirolo Quebranta 750ml", "Santiago Queirolo", "Bebidas Alcohólicas", "28.00", "22.50", "packshots/pisco_queirolo.png"},
        {"7750148000012", "Ron Cartavio Black 750ml", "Cartavio", "Bebidas Alcohólicas", "24.00", "19.00", "packshots/ron_cartavio.png"},
        {"7750170000012", "Vino Tabernero Borgoña Tinto 750ml", "Tabernero", "Bebidas Alcohólicas", "21.00", "16.80", "packshots/vino_tabernero.png"},
        {"5000267014005", "Whisky Johnnie Walker Red Label 750ml", "Johnnie Walker", "Bebidas Alcohólicas", "49.00", "39.00", "packshots/whisky_johnnie_walker.png"},
        {"849607000100", "Bebida Alcohólica Four Loko Gold Lata 473ml", "Four Loko", "Bebidas Alcohólicas", "10.50", "8.20", "packshots/four_loko_gold.png"},
        {"849607000117", "Bebida Alcohólica Four Loko Sandía Lata 473ml", "Four Loko", "Bebidas Alcohólicas", "10.50", "8.20", "packshots/four_loko_sandia.png"},
        {"849607000124", "Bebida Alcohólica Four Loko Blue Lata 473ml", "Four Loko", "Bebidas Alcohólicas", "10.50", "8.20", "packshots/four_loko_blue.png"},
        {"849607000131", "Bebida Alcohólica Four Loko Black Lata 473ml", "Four Loko", "Bebidas Alcohólicas", "10.50", "8.20", "packshots/four_loko_black.png"},
        {"7750111006502", "Bebida Preparada Mike's Hard Lemonade 350ml", "Mike's", "Bebidas Alcohólicas", "5.20", "4.00", "packshots/mikes_hard_lemonade.png"},
        {"7750111006519", "Bebida Preparada Mike's Hard Strawberry 350ml", "Mike's", "Bebidas Alcohólicas", "5.20", "4.00", "packshots/mikes_fresa.png"},
        {"7750111006526", "Bebida Preparada Mike's Hard Maracuyá 350ml", "Mike's", "Bebidas Alcohólicas", "5.20", "4.00", "packshots/mikes_maracuya.png"},
        {"5000291020010", "Bebida Preparada Smirnoff Ice Original 275ml", "Smirnoff", "Bebidas Alcohólicas", "6.50", "5.00", "packshots/smirnoff_ice.png"},
        {"7750170000203", "Chilcano de Pisco Tabernero Lata 310ml", "Tabernero", "Bebidas Alcohólicas", "6.50", "5.00", "packshots/chilcano_tabernero.png"},
        {"7750170000302", "Pisco Sour Tabernero Botella 700ml", "Tabernero", "Bebidas Alcohólicas", "22.00", "17.50", "packshots/pisco_sour_tabernero.png"},

        // --- 3. SNACKS Y PIQUEOS ---
        {"7758574005541", "Papas Fritas Lay's Clásicas 140g", "Lay's", "Snacks y Piqueos", "4.00", "3.10", "packshots/lays_clasicas_140g.png"},
        {"7758574005558", "Papas Fritas Lay's Onduladas 150g", "Lay's", "Snacks y Piqueos", "4.20", "3.20", "packshots/lays_onduladas.png"},
        {"7758574005510", "Doritos Mega Queso 45g", "Doritos", "Snacks y Piqueos", "1.80", "1.35", "packshots/doritos_queso_45g.png"},
        {"7758574005527", "Cheese Tris 150g", "Frito-Lay", "Snacks y Piqueos", "3.00", "2.30", "packshots/cheese_tris.png"},
        {"7758574005534", "Chizitos Queso Fiesta 120g", "Frito-Lay", "Snacks y Piqueos", "3.00", "2.30", "packshots/chizitos_queso.png"},
        {"7750670010818", "Cuates Picantes 100g", "Karinto", "Snacks y Piqueos", "2.00", "1.50", "packshots/cuates_picantes_100g.png"},
        {"7750670010825", "Tortees Picantes 140g", "Karinto", "Snacks y Piqueos", "3.00", "2.30", "packshots/tortees_picantes.png"},
        {"7758574005565", "Piqueo Snax Familiar 55g", "Frito-Lay", "Snacks y Piqueos", "2.00", "1.50", "packshots/piqueo_snax_55g.png"},
        {"7750670010832", "Chifle Piurano Salado 100g", "Karinto", "Snacks y Piqueos", "2.50", "1.90", "packshots/chifle_piurano.png"},
        {"7750670010849", "Maní Salado Karinto 100g", "Karinto", "Snacks y Piqueos", "2.00", "1.50", "packshots/mani_karinto.png"},

        // --- 4. LÁCTEOS Y DERIVADOS ---
        {"7750108003013", "Leche Gloria Azul Evaporada 400g", "Gloria", "Lácteos y Derivados", "4.20", "3.65", "packshots/leche_gloria_azul.png"},
        {"7750108003020", "Leche Gloria Roja Entera 400g", "Gloria", "Lácteos y Derivados", "4.20", "3.65", "packshots/leche_gloria_roja.png"},
        {"7750108003037", "Leche Gloria Light 400g", "Gloria", "Lácteos y Derivados", "4.20", "3.65", "packshots/leche_gloria_light.png"},
        {"7750108003044", "Leche Gloria Sin Lactosa 400g", "Gloria", "Lácteos y Derivados", "4.30", "3.70", "packshots/leche_gloria_sin_lactosa.png"},
        {"7750108003051", "Leche Chocolatada Gloria 1 Litro", "Gloria", "Lácteos y Derivados", "5.20", "4.20", "packshots/leche_chocolatada_gloria.png"},
        {"7750108003068", "Yogur Gloria Fresa 1 Litro", "Gloria", "Lácteos y Derivados", "6.20", "5.00", "packshots/yogur_gloria_fresa_1kg.png"},
        {"7750108003075", "Yogur Gloria Vainilla 1 Litro", "Gloria", "Lácteos y Derivados", "6.20", "5.00", "packshots/yogur_gloria_vainilla_1kg.png"},
        {"7750108003082", "Mantequilla con Sal Laive Barra 200g", "Laive", "Lácteos y Derivados", "7.50", "6.00", "packshots/mantequilla_laive.png"},
        {"7750108003099", "Margarina Manty Pote 225g", "Manty", "Lácteos y Derivados", "3.80", "2.90", "packshots/margarina_manty.png"},
        {"7613036615402", "Leche Condensada Nestlé Lata 393g", "Nestlé", "Lácteos y Derivados", "5.80", "4.60", "packshots/leche_condensada_nestle.png"},

        // --- 5. ABARROTES Y DESPENSA ---
        {"7750109004041", "Arroz Extra Costeño Bolsa 1kg", "Costeño", "Abarrotes y Despensa", "4.50", "3.80", "packshots/arroz_costeno.png"},
        {"7750109004058", "Arroz Superior Faraón Bolsa 1kg", "Faraón", "Abarrotes y Despensa", "4.30", "3.65", "packshots/arroz_faraon.png"},
        {"7750109004065", "Aceite Vegetal Primor Premium 900ml", "Primor", "Abarrotes y Despensa", "8.50", "7.20", "packshots/aceite_primor.png"},
        {"7750109004089", "Aceite Vegetal Cocinero 900ml", "Cocinero", "Abarrotes y Despensa", "7.50", "6.30", "packshots/aceite_cocinero.png"},
        {"7750109004096", "Azúcar Rubia Paramonga 1kg", "Paramonga", "Abarrotes y Despensa", "3.80", "3.20", "packshots/azucar_paramonga.png"},
        {"7750109004010", "Fideos Don Vittorio Spaghetti 450g", "Don Vittorio", "Abarrotes y Despensa", "2.80", "2.20", "packshots/fideos_spaghetti_don_vittorio.png"},
        {"7750114002088", "Fideos Molitalia Spaghetti 500g", "Molitalia", "Abarrotes y Despensa", "3.00", "2.30", "packshots/fideos_spaghetti_molitalia.png"},
        {"7750109004027", "Fideos Don Vittorio Codito 450g", "Don Vittorio", "Abarrotes y Despensa", "2.80", "2.20", "packshots/fideos_codito_don_vittorio.png"},
        {"7750109004034", "Fideos Lavaggi Canuto Corto 450g", "Lavaggi", "Abarrotes y Despensa", "2.30", "1.80", "packshots/fideos_canuto_lavaggi.png"},
        {"7750109004072", "Trozos de Atún Primor en Aceite 170g", "Primor", "Abarrotes y Despensa", "5.20", "4.20", "packshots/atun_primor.png"},
        {"7750109004102", "Filete de Atún Fanny en Aceite 140g", "Fanny", "Abarrotes y Despensa", "4.80", "3.80", "packshots/atun_fanny_140g.png"},
        {"7750109004119", "Mayonesa Alacena Doypack 850g", "Alacena", "Abarrotes y Despensa", "9.80", "7.80", "packshots/mayonesa_alacena_850g.png"},
        {"7750243030335", "Crema de Ají Tarí AlaCena Doypack 400g", "AlaCena", "Abarrotes y Despensa", "4.80", "3.80", "packshots/crema_tari_400g.png"},
        {"7750114006079", "Salsa de Rocoto Uchucuta AlaCena Doypack 400g", "AlaCena", "Abarrotes y Despensa", "5.80", "4.60", "packshots/salsa_uchucuta_alacena.png"},
        {"7750109004126", "Salsa de Tomate Tuco Sibarita 260g", "Sibarita", "Abarrotes y Despensa", "2.80", "2.20", "packshots/tuco_sibarita.png"},
        {"7750109004133", "Sal Yodada Marina Emsal 1kg", "Emsal", "Abarrotes y Despensa", "1.50", "1.00", "packshots/sal_emsal.png"},

        // --- 6. GOLOSINAS Y CHOCOLATES ---
        {"7613036615303", "Chocolate con Leche Sublime Clásico 100g", "Nestlé", "Golosinas y Chocolates", "3.80", "3.00", "packshots/chocolate_sublime_100g.png"},
        {"7613036615310", "Chocolate Triángulo D'Onofrio 30g", "D'Onofrio", "Golosinas y Chocolates", "2.00", "1.50", "packshots/chocolate_triangulo.png"},
        {"7750115010035", "Galleta Cua Cua Chocolate 18g", "Field", "Golosinas y Chocolates", "1.00", "0.70", "packshots/galleta_cua_cua.png"},
        {"7750115010042", "Galleta Doña Pepa 23g", "Field", "Golosinas y Chocolates", "1.00", "0.70", "packshots/galleta_dona_pepa.png"},
        {"7750115010059", "Galleta Casino Fresa 68g", "Victoria", "Golosinas y Chocolates", "1.00", "0.75", "packshots/galleta_casino.png"},
        {"7750115010066", "Galleta Margarita Clásica 80g", "Sayón", "Golosinas y Chocolates", "1.00", "0.75", "packshots/galleta_margarita.png"},
        {"7750115010073", "Galleta Tentación Chocolate 70g", "Victoria", "Golosinas y Chocolates", "1.00", "0.75", "packshots/galleta_tentacion.png"},
        {"7750115010080", "Galleta Oreo Original Tubo 108g", "Oreo", "Golosinas y Chocolates", "2.50", "1.90", "packshots/galleta_oreo.png"},
        {"7750115010097", "Pastillas Halls Extra Fuerte Menta", "Halls", "Golosinas y Chocolates", "1.00", "0.70", "packshots/halls_menta.png"},
        {"7750115010103", "Caramelos Chicho Surtido Paquete 100g", "Chicho", "Golosinas y Chocolates", "2.50", "1.90", "packshots/caramelos_chicho.png"},

        // --- 7. EMBUTIDOS Y FIAMBRERÍA ---
        {"7750107002016", "Hot Dog de Pollo San Fernando 500g", "San Fernando", "Embutidos y Fiambrería", "5.80", "4.60", "packshots/hot_dog_san_fernando.png"},
        {"7750107002023", "Jamonada de Pollo San Fernando 450g", "San Fernando", "Embutidos y Fiambrería", "6.50", "5.10", "packshots/jamonada_san_fernando.png"},
        {"7750107002030", "Salchicha Huachana Laive 250g", "Laive", "Embutidos y Fiambrería", "4.80", "3.80", "packshots/salchicha_huachana.png"},
        {"7750107002047", "Tocino Ahumado en Tiras Braedt 170g", "Braedt", "Embutidos y Fiambrería", "8.50", "6.80", "packshots/tocino_braedt.png"},
        {"7750107002054", "Chorizo Parrillero San Fernando pack x4", "San Fernando", "Embutidos y Fiambrería", "7.50", "5.90", "packshots/chorizo_parrillero.png"},
        {"7750107002061", "Queso Edam Laminado Laive 200g", "Laive", "Embutidos y Fiambrería", "8.50", "6.80", "packshots/queso_edam.png"},
        {"7750107002078", "Queso Fresco Bonlé Gloria 400g", "Gloria", "Embutidos y Fiambrería", "9.50", "7.60", "packshots/queso_fresco_bonle.png"},
        {"7750107002085", "Jamón del País Braedt 150g", "Braedt", "Embutidos y Fiambrería", "8.20", "6.50", "packshots/jamon_del_pais.png"},

        // --- 8. PANADERÍA Y DESAYUNO ---
        {"7750116011018", "Pan de Molde Blanco Bimbo Chico 400g", "Bimbo", "Panadería y Desayuno", "4.80", "3.80", "packshots/pan_bimbo_blanco.png"},
        {"7501000133404", "Pan Bimbo Artesano Rebanada Gruesa 500g", "Bimbo", "Panadería y Desayuno", "7.50", "6.00", "packshots/pan_bimbo_artesano.png"},
        {"7750727014189", "Pan de Molde Bimbo Blanco Familiar 590g", "Bimbo", "Panadería y Desayuno", "6.50", "5.10", "packshots/pan_bimbo_blanco.png"},
        {"7750116011025", "Pan de Molde Bimbo Integral 400g", "Bimbo", "Panadería y Desayuno", "5.20", "4.10", "packshots/pan_bimbo_integral.png"},
        {"7750116011032", "Mermelada de Fresa Gloria Vaso 310g", "Gloria", "Panadería y Desayuno", "4.50", "3.50", "packshots/mermelada_gloria.png"},
        {"7750116011049", "Café Soluble Nescafé Tradición Frasco 50g", "Nescafé", "Panadería y Desayuno", "7.50", "6.00", "packshots/cafe_nescafe.png"},
        {"7750116011056", "Avena Precocida 3 Ositos Bolsa 250g", "3 Ositos", "Panadería y Desayuno", "2.00", "1.50", "packshots/avena_tres_ositos.png"},
        {"7750116011063", "Té Herbi Clásico Caja x25 bolsitas", "Herbi", "Panadería y Desayuno", "2.80", "2.10", "packshots/te_herbi.png"},
        {"7750116011070", "Manzanilla Herbi Caja x25 bolsitas", "Herbi", "Panadería y Desayuno", "2.80", "2.10", "packshots/manzanilla_herbi.png"},

        // --- 9. LIMPIEZA Y CUIDADO DEL HOGAR ---
        {"7750114009015", "Detergente Bolívar Blanco Activo 850g", "Bolívar", "Limpieza y Cuidado del Hogar", "8.50", "6.90", "packshots/detergente_bolivar.png"},
        {"7750114009022", "Detergente Ace Limpieza Completa 750g", "Ace", "Limpieza y Cuidado del Hogar", "7.50", "6.00", "packshots/detergente_ace.png"},
        {"7750114009039", "Detergente Opal Ultra 750g", "Opal", "Limpieza y Cuidado del Hogar", "7.50", "6.00", "packshots/detergente_opal.png"},
        {"7759918006163", "Lavavajilla Líquido Ayudín Lima Limón 900ml", "Ayudín", "Limpieza y Cuidado del Hogar", "5.80", "4.50", "packshots/lavavajilla_ayudin.png"},
        {"7750114009046", "Lavavajillas Líquido Sapolio Limón 750ml", "Sapolio", "Limpieza y Cuidado del Hogar", "4.50", "3.50", "packshots/lavavajilla_sapolio.png"},
        {"7750114009060", "Lejía Clorox Tradicional 1 Litro", "Clorox", "Limpieza y Cuidado del Hogar", "3.20", "2.50", "packshots/lejia_clorox.png"},
        {"7750114009077", "Limpiador Multiusos Poett Lavanda 900ml", "Poett", "Limpieza y Cuidado del Hogar", "4.50", "3.50", "packshots/limpiador_poett.png"},
        {"7750114009084", "Suavizante Suavitel Fresca Primavera 850ml", "Suavitel", "Limpieza y Cuidado del Hogar", "5.50", "4.30", "packshots/suavizante_suavitel.png"},
        {"7750114009091", "Esponja Verde Scotch Brite Clásica", "Scotch-Brite", "Limpieza y Cuidado del Hogar", "1.80", "1.30", "packshots/esponja_scotch.png"},
        {"7750114009107", "Bolsas de Basura Negras Grande x10", "Bolsas del Perú", "Limpieza y Cuidado del Hogar", "2.50", "1.80", "packshots/bolsas_basura.png"},

        // --- 10. CUIDADO PERSONAL Y DENTAL ---
        {"7750113008025", "Crema Dental Colgate Total 12 Limpieza 75ml", "Colgate", "Cuidado Personal y Dental", "4.50", "3.50", "packshots/colgate_total12.png"},
        {"7750113008032", "Crema Dental Colgate Triple Acción 75ml", "Colgate", "Cuidado Personal y Dental", "3.50", "2.60", "packshots/colgate_triple_accion.png"},
        {"7750113008018", "Crema Dental Kolynos Triple Limpieza 120g", "Kolynos", "Cuidado Personal y Dental", "3.00", "2.20", "packshots/kolynos.png"},
        {"7750113008049", "Cepillo Dental Colgate Zig Zag Medio", "Colgate", "Cuidado Personal y Dental", "3.50", "2.50", "packshots/cepillo_colgate.png"},
        {"7750113008056", "Jabón de Tocador Dove Blanco 90g", "Dove", "Cuidado Personal y Dental", "3.20", "2.40", "packshots/jabon_dove.png"},
        {"7750113008063", "Jabón Camay Clásico 125g", "Camay", "Cuidado Personal y Dental", "2.50", "1.80", "packshots/jabon_camay.png"},
        {"7750113008070", "Shampoo Head & Shoulders Limpieza Renovadora 375ml", "Head & Shoulders", "Cuidado Personal y Dental", "14.50", "11.50", "packshots/shampoo_head_shoulders.png"},
        {"7750113008087", "Shampoo Pantene Restauración 375ml", "Pantene", "Cuidado Personal y Dental", "14.50", "11.50", "packshots/shampoo_pantene.png"},
        {"7750113008094", "Desodorante Rexona Men Aerosol 150ml", "Rexona", "Cuidado Personal y Dental", "10.50", "8.40", "packshots/rexona_men.png"},
        {"7750113008100", "Desodorante Rexona Women Aerosol 150ml", "Rexona", "Cuidado Personal y Dental", "10.50", "8.40", "packshots/rexona_women.png"},
        {"7750113008117", "Papel Higiénico Suave Rindemax x4 rollos", "Suave", "Cuidado Personal y Dental", "5.00", "3.90", "packshots/papel_higienico_suave.png"},
        {"7750113008148", "Papel Higiénico Elite Dúo Doble Hoja x4 rollos", "Elite", "Cuidado Personal y Dental", "6.00", "4.70", "packshots/papel_higienico_elite.png"},
        {"7750113008162", "Papel Higiénico Paracas Black Premium x4 rollos", "Paracas", "Cuidado Personal y Dental", "5.50", "4.30", "packshots/papel_higienico_paracas.png"},
        {"7750113008124", "Toallas Higiénicas Nosotras x10", "Nosotras", "Cuidado Personal y Dental", "3.50", "2.70", "packshots/toallas_nosotras.png"},

        // --- 11. HELADOS Y CONGELADOS ---
        {"7750110005017", "Helado Sublime D'Onofrio Paleta", "D'Onofrio", "Helados y Congelados", "2.50", "1.90", "packshots/helado_sublime.png"},
        {"7750110005178", "Helado D'Onofrio Sándwich Clásico", "D'Onofrio", "Helados y Congelados", "2.50", "1.90", "packshots/helado_sandwich_donofrio.png"},
        {"7750110005062", "Helado Jet Chocolate D'Onofrio Paleta", "D'Onofrio", "Helados y Congelados", "2.50", "1.90", "packshots/helado_jet.png"},
        {"7750110005024", "Helado Sin Parar Lúcuma D'Onofrio Copa", "D'Onofrio", "Helados y Congelados", "4.00", "3.00", "packshots/helado_sin_parar.png"},
        {"7750110005031", "Helado Frío Rico Vainilla D'Onofrio Cono", "D'Onofrio", "Helados y Congelados", "4.50", "3.40", "packshots/helado_frio_rico.png"},
        {"7750110005048", "Helado Bombones D'Onofrio Caja x8", "D'Onofrio", "Helados y Congelados", "5.50", "4.20", "packshots/helado_bombones.png"},
        {"7750110005055", "Helado Peziduri Tricolor D'Onofrio 900ml", "D'Onofrio", "Helados y Congelados", "10.50", "8.40", "packshots/helado_peziduri_tricolor_900ml.png"},

        // --- 12. CIGARRILLOS Y TABACO ---
        {"7750112007028", "Cigarrillos Lucky Strike Doble Click Cajetilla x20", "Lucky Strike", "Cigarrillos y Tabaco", "18.00", "15.00", "packshots/cigarros_lucky_strike.png"},
        {"7751201001169", "Cigarrillos Marlboro Summer Mix Cajetilla 20", "Marlboro", "Cigarrillos y Tabaco", "19.00", "16.00", "packshots/cigarros_marlboro_20.png"},
        {"7750112007035", "Cigarrillos Hamilton Rojo Cajetilla x20", "Hamilton", "Cigarrillos y Tabaco", "15.00", "12.50", "packshots/cigarros_hamilton.png"},
        {"7750112007042", "Cigarrillos Pall Mall Blue Cajetilla x20", "Pall Mall", "Cigarrillos y Tabaco", "15.00", "12.50", "packshots/cigarros_pall_mall.png"},
        {"7750112007059", "Fósforos La Llama Paquete x10 cajas", "La Llama", "Cigarrillos y Tabaco", "2.00", "1.40", "packshots/fosforos_la_llama.png"},
        {"7750112007066", "Encendedor Tokai Descartable", "Tokai", "Cigarrillos y Tabaco", "1.50", "1.00", "packshots/encendedor_tokai.png"}
    };

    /**
     * Asegura que existan las 12 categorías canónicas oficiales para la bodega indicada.
     */
    @Transactional
    public Map<String, Categoria> asegurarCategoriasCanonicas(Bodega bodega) {
        Map<String, Categoria> map = new HashMap<>();
        if (bodega == null || bodega.getIdBodega() == null) return map;

        Long idBodega = bodega.getIdBodega();
        for (String[] def : CATEGORIAS_CANONICAS) {
            String nombre = def[0];
            String descripcion = def[1];

            Optional<Categoria> opt = categoriaRepository.findByBodega_IdBodegaAndNombreIgnoreCase(idBodega, nombre);
            Categoria cat;
            if (opt.isPresent()) {
                cat = opt.get();
                if (!Boolean.TRUE.equals(cat.getEstado())) {
                    cat.setEstado(true);
                    cat = categoriaRepository.save(cat);
                }
            } else {
                cat = new Categoria();
                cat.setNombre(nombre);
                cat.setDescripcion(descripcion);
                cat.setEstado(true);
                cat.setBodega(bodega);
                cat = categoriaRepository.save(cat);
            }
            map.put(nombre.toLowerCase().trim(), cat);
        }
        return map;
    }

    /**
     * Sanitiza la base de datos de todas las bodegas:
     * 1. Elimina duplicados de Agua San Mateo preservando historial de ventas/compras.
     * 2. Reasigna y purga categorías basura como 'Bebidas Refrescantes 128/556/431/658/342'.
     * 3. Mergea categorías redundantes en las 12 canónicas y elimina atajos huérfanos.
     */
    @Transactional
    public void sanitizarCategoriasYAtajos() {
        log.info("[StarterPackService] Iniciando sanitización integral de categorías y atajos POS...");

        try {
            // A. Primero asegurar que todas las bodegas activas tengan las 12 categorías canónicas de destino
            List<Bodega> bodegas = bodegaRepository.findAll();
            for (Bodega b : bodegas) {
                if (b != null && b.getIdBodega() != null) {
                    asegurarCategoriasCanonicas(b);
                }
            }

            // B. Consolidar productos duplicados de Agua San Mateo (IDs 130, 132, 133, 134 -> ID 131)
            try {
                jdbcTemplate.execute("UPDATE ventas_detalles SET id_producto = 131 WHERE id_producto IN (130, 132, 133, 134)");
            } catch (Exception e) {
                log.debug("[StarterPackService] Reasignar ventas_detalles omitido: {}", e.getMessage());
            }
            try {
                jdbcTemplate.execute("UPDATE compras_detalles SET id_producto = 131 WHERE id_producto IN (130, 132, 133, 134)");
            } catch (Exception e) {
                log.debug("[StarterPackService] Reasignar compras_detalles omitido: {}", e.getMessage());
            }
            try {
                jdbcTemplate.execute("UPDATE movimientos_inventario SET id_producto = 131 WHERE id_producto IN (130, 132, 133, 134)");
            } catch (Exception e) {
                log.debug("[StarterPackService] Reasignar movimientos_inventario omitido: {}", e.getMessage());
            }
            try {
                jdbcTemplate.execute("DELETE FROM productos WHERE id_producto IN (130, 132, 133, 134)");
            } catch (Exception e) {
                log.debug("[StarterPackService] Eliminar duplicados Agua San Mateo omitido: {}", e.getMessage());
            }

            // C. Mapear cualquier producto en categorías 'Bebidas Refrescantes%' hacia la canónica 'Gaseosas y Bebidas'
            jdbcTemplate.execute(
                "UPDATE productos p " +
                "SET id_categoria = c_dest.id_categoria " +
                "FROM categorias c_orig " +
                "JOIN categorias c_dest ON c_dest.id_bodega = c_orig.id_bodega AND c_dest.nombre = 'Gaseosas y Bebidas' " +
                "WHERE p.id_categoria = c_orig.id_categoria " +
                "  AND c_orig.nombre ILIKE 'Bebidas Refrescantes%' " +
                "  AND c_orig.id_categoria <> c_dest.id_categoria"
            );

            // D. Eliminar categorías 'Bebidas Refrescantes%'
            jdbcTemplate.execute("DELETE FROM categorias WHERE nombre ILIKE 'Bebidas Refrescantes%'");

            // E. Mapear pares redundantes a las 12 canónicas
            String[][] paresRedundantes = {
                {"Bebidas y Gaseosas", "Gaseosas y Bebidas"},
                {"Bebidas", "Gaseosas y Bebidas"},
                {"Licores y Cervezas", "Bebidas Alcohólicas"},
                {"Snacks y Golosinas", "Snacks y Piqueos"},
                {"Lácteos y Huevos", "Lácteos y Derivados"},
                {"Abarrotes y Fideos", "Abarrotes y Despensa"},
                {"Helados y Postres", "Helados y Congelados"},
                {"Cuidado Personal", "Cuidado Personal y Dental"},
                {"Limpieza del Hogar", "Limpieza y Cuidado del Hogar"},
                {"Cigarrillos y Tabacos", "Cigarrillos y Tabaco"}
            };

            for (String[] par : paresRedundantes) {
                String origen = par[0];
                String destino = par[1];

                try {
                    jdbcTemplate.update(
                        "UPDATE productos p " +
                        "SET id_categoria = c_dest.id_categoria " +
                        "FROM categorias c_orig " +
                        "JOIN categorias c_dest ON c_dest.id_bodega = c_orig.id_bodega AND c_dest.nombre = ? " +
                        "WHERE p.id_categoria = c_orig.id_categoria " +
                        "  AND c_orig.nombre = ? " +
                        "  AND c_orig.id_categoria <> c_dest.id_categoria",
                        destino, origen
                    );
                } catch (Exception ex) {
                    log.warn("[StarterPackService] Error unificando categoría '{}' a '{}': {}", origen, destino, ex.getMessage());
                }
            }

            // F. Eliminar categorías redundantes que ya quedaron con 0 productos
            jdbcTemplate.execute(
                "DELETE FROM categorias " +
                "WHERE nombre IN (" +
                "  'Bebidas', 'Bebidas y Gaseosas', 'Licores y Cervezas', 'Snacks y Golosinas', " +
                "  'Lácteos y Huevos', 'Abarrotes y Fideos', 'Helados y Postres', 'Cuidado Personal', " +
                "  'Limpieza del Hogar', 'Cigarrillos y Tabacos' " +
                ") " +
                "AND id_categoria NOT IN (SELECT DISTINCT id_categoria FROM productos WHERE id_categoria IS NOT NULL)"
            );

            log.info("[StarterPackService] Sanitización de categorías y atajos completada exitosamente.");
        } catch (Exception e) {
            log.error("[StarterPackService] Error durante la sanitización de categorías: {}", e.getMessage(), e);
        }
    }

    /**
     * Clona el Starter Pack completo de productos comerciales peruanos para una nueva bodega.
     * Los productos se inicializan con stock = 0.000 para no adulterar el inventario inicial del dueño,
     * pero quedan listos para venta y recepción de compras.
     */
    @Transactional
    public void provisionarStarterPackParaBodega(Bodega bodega) {
        if (bodega == null || bodega.getIdBodega() == null) return;
        Long idBodega = bodega.getIdBodega();

        log.info("[StarterPackService] Provisionando Starter Pack comercial para Bodega '{}' (ID: {})...",
                bodega.getNombreComercial(), idBodega);

        Map<String, Categoria> categoriasMap = asegurarCategoriasCanonicas(bodega);

        Categoria fallbackCat = categoriaRepository.findByBodega_IdBodegaAndEstadoTrue(idBodega).stream()
                .findFirst().orElse(null);

        List<Producto> existentes = productoRepository.findByBodega_IdBodega(idBodega);
        Map<String, Producto> porCodigoBarras = new HashMap<>();
        Set<String> codigosExistentes = new HashSet<>();
        for (Producto prod : existentes) {
            if (prod.getCodigoBarras() != null && !prod.getCodigoBarras().isBlank()) {
                porCodigoBarras.putIfAbsent(prod.getCodigoBarras().trim(), prod);
            }
            if (prod.getCodigo() != null && !prod.getCodigo().isBlank()) {
                codigosExistentes.add(prod.getCodigo().trim());
            }
        }

        Set<Producto> porGuardar = new LinkedHashSet<>();
        int creados = 0;
        int actualizados = 0;

        List<StarterPackItemRecord> itemsToClone = new ArrayList<>();
        try {
            if (starterPackPresetRepository != null) {
                List<StarterPackPreset> dbPresets = starterPackPresetRepository.findByActivoTrueOrderByIdPresetAsc();
                if (dbPresets != null && !dbPresets.isEmpty()) {
                    for (StarterPackPreset p : dbPresets) {
                        itemsToClone.add(new StarterPackItemRecord(
                                p.getCodigoBarras(),
                                p.getNombre(),
                                p.getMarca(),
                                p.getCategoria(),
                                p.getPrecioVenta(),
                                p.getPrecioCosto(),
                                p.getImagenUrl()
                        ));
                    }
                }
            }
        } catch (Exception e) {
            log.warn("[StarterPackService] Error al consultar preset global en BD, usando memoria: {}", e.getMessage());
        }

        if (itemsToClone.isEmpty()) {
            for (String[] pData : PRODUCTOS_STARTER_PACK) {
                itemsToClone.add(new StarterPackItemRecord(
                        pData[0], pData[1], pData[2], pData[3],
                        new BigDecimal(pData[4]), new BigDecimal(pData[5]), pData[6]
                ));
            }
        }

        for (StarterPackItemRecord item : itemsToClone) {
            String codigoBarras = item.codigoBarras();
            String nombre = item.nombre();
            String marca = item.marca();
            String catNombre = item.catNombre();
            BigDecimal venta = item.venta();
            BigDecimal costo = item.costo();
            String imagenUrl = item.imagenUrl();

            Categoria categoria = categoriasMap.getOrDefault(catNombre.toLowerCase().trim(), fallbackCat);
            if (categoria == null) continue;

            Producto existente = codigoBarras != null ? porCodigoBarras.get(codigoBarras.trim()) : null;
            if (existente != null) {
                boolean mod = false;
                if ((existente.getImagenUrl() == null || existente.getImagenUrl().isBlank()) && imagenUrl != null) {
                    existente.setImagenUrl(imagenUrl);
                    mod = true;
                }
                if ((existente.getMarca() == null || existente.getMarca().isBlank()) && marca != null) {
                    existente.setMarca(marca);
                    mod = true;
                }
                if (existente.getCategoria() == null) {
                    existente.setCategoria(categoria);
                    mod = true;
                }
                if (existente.getPrecioVenta() == null || existente.getPrecioVenta().compareTo(BigDecimal.ZERO) <= 0) {
                    existente.setPrecioVenta(venta);
                    mod = true;
                }
                if (existente.getPrecioCosto() == null || existente.getPrecioCosto().compareTo(BigDecimal.ZERO) <= 0) {
                    existente.setPrecioCosto(costo);
                    mod = true;
                }
                if (mod) {
                    porGuardar.add(existente);
                    actualizados++;
                }
                continue;
            }

            // Generar codigo unico para el producto dentro del tenant sin consultas N+1
            String codigoBase = "PROD-" + codigoBarras;
            String codigo = codigoBase;
            if (codigosExistentes.contains(codigo)) {
                codigo = codigoBase + "-" + (System.currentTimeMillis() % 1000);
                int sufijo = 1;
                while (codigosExistentes.contains(codigo)) {
                    codigo = codigoBase + "-" + sufijo++;
                }
            }
            codigosExistentes.add(codigo);

            Producto p = new Producto();
            p.setCodigo(codigo);
            p.setCodigoBarras(codigoBarras);
            p.setNombre(nombre);
            p.setMarca(marca);
            p.setPrecioVenta(venta);
            p.setPrecioCosto(costo);
            p.setStockActual(BigDecimal.ZERO); // Inventario inicial en 0 para integridad contable
            p.setStockMinimo(new BigDecimal("5.000"));
            p.setControlaVencimiento(false);
            p.setImagenUrl(imagenUrl);
            p.setCategoria(categoria);
            p.setBodega(bodega);
            p.setEstado(true);

            porGuardar.add(p);
            if (codigoBarras != null && !codigoBarras.isBlank()) {
                porCodigoBarras.putIfAbsent(codigoBarras.trim(), p);
            }
            creados++;
        }

        if (!porGuardar.isEmpty()) {
            productoRepository.saveAll(porGuardar);
        }

        log.info("[StarterPackService] Starter Pack completado para Bodega '{}': {} creados, {} enriquecidos.",
                bodega.getNombreComercial(), creados, actualizados);
    }

    /**
     * Enriquecimiento del catálogo de Bodega Karliz: preserva stocks actuales existentes,
     * agrega las bebidas y productos faltantes con stock = 0, y actualiza URLs de packshots.
     */
    @Transactional
    public void enriquecerCatalogoBodegaKarliz(Bodega bodegaKarliz) {
        if (bodegaKarliz == null || bodegaKarliz.getIdBodega() == null) return;
        provisionarStarterPackParaBodega(bodegaKarliz);
    }

    /**
     * Actualiza los precios de venta y costo de todos los productos en todas las bodegas registradas
     * para reflejar tarifas reales de bodega de barrio peruana (cómodas y competitivas de calle).
     */
    @Transactional
    public void actualizarPreciosBodegasRegistradas() {
        log.info("[StarterPackService] Actualizando precios de todas las bodegas registradas a tarifas reales de calle...");
        int totalActualizados = 0;
        for (String[] pData : PRODUCTOS_STARTER_PACK) {
            String codigoBarras = pData[0];
            String nombre = pData[1];
            BigDecimal venta = new BigDecimal(pData[4]);
            BigDecimal costo = new BigDecimal(pData[5]);

            try {
                int count = jdbcTemplate.update(
                    "UPDATE productos SET precio_venta = ?, precio_costo = ? WHERE codigo_barras = ?",
                    venta, costo, codigoBarras
                );
                totalActualizados += count;
            } catch (Exception e) {
                log.warn("[StarterPackService] Error actualizando precio por código de barras {}: {}", codigoBarras, e.getMessage());
            }

            // También actualizar por nombre si no tiene código de barras
            try {
                jdbcTemplate.update(
                    "UPDATE productos SET precio_venta = ?, precio_costo = ? WHERE (codigo_barras IS NULL OR codigo_barras = '') AND nombre ILIKE ?",
                    venta, costo, "%" + nombre + "%"
                );
            } catch (Exception e) {
                log.debug("[StarterPackService] Actualización por nombre omitida: {}", e.getMessage());
            }
        }
        log.info("[StarterPackService] Precios actualizados en bodegas registradas: {} registros impactados.", totalActualizados);
    }

    // =========================================================================
    // GESTIÓN DEL PRESET GLOBAL PARA EL SUPERADMIN
    // =========================================================================

    @Transactional
    public void inicializarPresetGlobalSiVacio() {
        if (starterPackPresetRepository == null) return;
        try {
            long count = starterPackPresetRepository.count();
            if (count > 0) return;

            log.info("[StarterPackService] Inicializando catálogo preset global en base de datos...");
            List<StarterPackPreset> presets = new ArrayList<>();
            for (String[] pData : PRODUCTOS_STARTER_PACK) {
                presets.add(StarterPackPreset.builder()
                        .codigoBarras(pData[0].trim())
                        .nombre(pData[1].trim())
                        .marca(pData[2] != null ? pData[2].trim() : null)
                        .categoria(pData[3].trim())
                        .precioVenta(new BigDecimal(pData[4]))
                        .precioCosto(new BigDecimal(pData[5]))
                        .imagenUrl(pData[6] != null ? pData[6].trim() : null)
                        .activo(true)
                        .build());
            }
            starterPackPresetRepository.saveAll(presets);
            log.info("[StarterPackService] Preset global inicializado exitosamente con {} productos.", presets.size());
        } catch (Exception e) {
            log.warn("[StarterPackService] Aviso al inicializar preset global: {}", e.getMessage());
        }
    }

    @Transactional(readOnly = true)
    public List<StarterPackPresetDTO> listarPresetGlobal() {
        inicializarPresetGlobalSiVacio();
        return starterPackPresetRepository.findAllByOrderByIdPresetAsc().stream()
                .map(this::mapPresetToDTO)
                .toList();
    }

    @Transactional
    public StarterPackPresetDTO crearPresetItem(StarterPackPresetDTO dto) {
        if (dto.getCodigoBarras() == null || dto.getCodigoBarras().isBlank()) {
            throw new IllegalArgumentException("El código de barras es obligatorio.");
        }
        String ean = dto.getCodigoBarras().trim();
        if (starterPackPresetRepository.existsByCodigoBarras(ean)) {
            throw new IllegalArgumentException("Ya existe un producto con el código de barras '" + ean + "' en el preset global.");
        }
        StarterPackPreset entity = StarterPackPreset.builder()
                .codigoBarras(ean)
                .nombre(dto.getNombre().trim())
                .marca(dto.getMarca() != null ? dto.getMarca().trim() : null)
                .categoria(dto.getCategoria().trim())
                .precioVenta(dto.getPrecioVenta() != null ? dto.getPrecioVenta() : BigDecimal.ZERO)
                .precioCosto(dto.getPrecioCosto() != null ? dto.getPrecioCosto() : BigDecimal.ZERO)
                .imagenUrl(dto.getImagenUrl() != null ? dto.getImagenUrl().trim() : null)
                .activo(dto.getActivo() != null ? dto.getActivo() : true)
                .build();
        return mapPresetToDTO(starterPackPresetRepository.save(entity));
    }

    @Transactional
    public StarterPackPresetDTO actualizarPresetItem(Long id, StarterPackPresetDTO dto) {
        StarterPackPreset entity = starterPackPresetRepository.findById(id)
                .orElseThrow(() -> new NoSuchElementException("Producto del preset no encontrado con ID: " + id));

        if (dto.getCodigoBarras() != null && !dto.getCodigoBarras().isBlank()) {
            String nuevoEan = dto.getCodigoBarras().trim();
            if (!nuevoEan.equalsIgnoreCase(entity.getCodigoBarras()) && starterPackPresetRepository.existsByCodigoBarras(nuevoEan)) {
                throw new IllegalArgumentException("Ya existe otro producto con el código de barras '" + nuevoEan + "'.");
            }
            entity.setCodigoBarras(nuevoEan);
        }
        if (dto.getNombre() != null && !dto.getNombre().isBlank()) {
            entity.setNombre(dto.getNombre().trim());
        }
        if (dto.getMarca() != null) {
            entity.setMarca(dto.getMarca().trim());
        }
        if (dto.getCategoria() != null && !dto.getCategoria().isBlank()) {
            entity.setCategoria(dto.getCategoria().trim());
        }
        if (dto.getPrecioVenta() != null) {
            entity.setPrecioVenta(dto.getPrecioVenta());
        }
        if (dto.getPrecioCosto() != null) {
            entity.setPrecioCosto(dto.getPrecioCosto());
        }
        if (dto.getImagenUrl() != null) {
            entity.setImagenUrl(dto.getImagenUrl().trim());
        }
        if (dto.getActivo() != null) {
            entity.setActivo(dto.getActivo());
        }
        return mapPresetToDTO(starterPackPresetRepository.save(entity));
    }

    @Transactional
    public void eliminarPresetItem(Long id) {
        if (!starterPackPresetRepository.existsById(id)) {
            throw new NoSuchElementException("Producto del preset no encontrado con ID: " + id);
        }
        starterPackPresetRepository.deleteById(id);
    }

    @Transactional
    public List<StarterPackPresetDTO> restablecerPresetGlobal() {
        starterPackPresetRepository.deleteAll();
        inicializarPresetGlobalSiVacio();
        return starterPackPresetRepository.findAllByOrderByIdPresetAsc().stream()
                .map(this::mapPresetToDTO)
                .toList();
    }

    private StarterPackPresetDTO mapPresetToDTO(StarterPackPreset p) {
        return StarterPackPresetDTO.builder()
                .idPreset(p.getIdPreset())
                .codigoBarras(p.getCodigoBarras())
                .nombre(p.getNombre())
                .marca(p.getMarca())
                .categoria(p.getCategoria())
                .precioVenta(p.getPrecioVenta())
                .precioCosto(p.getPrecioCosto())
                .imagenUrl(p.getImagenUrl())
                .activo(p.getActivo())
                .build();
    }

    public record StarterPackItemRecord(
            String codigoBarras,
            String nombre,
            String marca,
            String catNombre,
            BigDecimal venta,
            BigDecimal costo,
            String imagenUrl
    ) {}
}
