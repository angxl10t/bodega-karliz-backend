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
        {"Cigarrillos y Tabaco", "Cigarrillos en cajetilla, fósforos y encendedores"},
        {"Mascotas y Alimento", "Comida para perros y gatos en bolsa, sobres húmedos y paté en lata"}
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
        {"7750112007066", "Encendedor Tokai Descartable", "Tokai", "Cigarrillos y Tabaco", "1.50", "1.00", "packshots/encendedor_tokai.png"},

        // --- 13. EXPANSIÓN COMERCIAL DE ALTA ROTACIÓN (PERÚ) ---
        {"7613036615501", "Bebida Achocolatada Milo Nestlé Lata 400g", "Nestlé", "Panadería y Desayuno", "16.50", "13.40", "packshots/milo_nestle_400g.png"},
        {"7613036615518", "Chocolate Princesa D'Onofrio Clásico 30g", "D'Onofrio", "Golosinas y Chocolates", "2.00", "1.50", "packshots/chocolate_princesa.png"},
        {"7750115010202", "Galleta Pícaras Bañadas en Chocolate 40g", "Costa", "Golosinas y Chocolates", "1.20", "0.85", "packshots/galleta_picaras.png"},
        {"7750109004300", "Sopa Instantánea Ajinomen Pollo 80g", "Ajinomoto", "Abarrotes y Despensa", "2.00", "1.50", "packshots/ajinomen_pollo.png"},
        {"7750243030410", "Ketchup AlaCena Doypack 380g", "AlaCena", "Abarrotes y Despensa", "5.50", "4.30", "packshots/ketchup_alacena_380g.png"},
        {"7750109004317", "Sillao Kikko Clásico Botella 500ml", "Kikko", "Abarrotes y Despensa", "4.20", "3.30", "packshots/sillao_kikko_500ml.png"},
        {"7750109004324", "Filete de Atún Campomar en Aceite Vegetal 170g", "Campomar", "Abarrotes y Despensa", "5.80", "4.60", "packshots/atun_campomar_170g.png"},
        {"7750108003204", "Huevos Pardos La Calera Bandeja x15 unidades", "La Calera", "Lácteos y Derivados", "9.50", "7.80", "packshots/huevos_la_calera_x15.png"},
        {"7613036615525", "Leche Evaporada Ideal Cremosa Nestlé 395g", "Nestlé", "Lácteos y Derivados", "4.00", "3.40", "packshots/leche_ideal_cremosa.png"},
        {"7750670010917", "Papas Artesanales Inka Chips Sal Marina 135g", "Inka Chips", "Snacks y Piqueos", "6.50", "5.10", "packshots/inka_chips_sal_marina.png"},
        {"7758574005596", "Cheese Tris Personal 44g", "Frito-Lay", "Snacks y Piqueos", "1.50", "1.10", "packshots/cheese_tris_44g.png"},
        {"7750182000710", "Bebida Rehidratante Powerade Mountain Blast 500ml", "Powerade", "Gaseosas y Bebidas", "2.80", "2.15", "packshots/powerade_mountain_blast.png"},
        {"7750114009206", "Suavizante Downy Amanecer Botella 750ml", "Downy", "Limpieza y Cuidado del Hogar", "9.50", "7.60", "packshots/suavizante_downy_750ml.png"},
        {"7750114009213", "Jabón de Lavar Ropa Bolívar Clásico Azul 190g", "Bolívar", "Limpieza y Cuidado del Hogar", "3.50", "2.75", "packshots/jabon_bolivar_azul.png"},
        {"7750110005185", "Helado Frío Rico D'Onofrio Multipack x4", "D'Onofrio", "Helados y Congelados", "14.50", "11.50", "packshots/helado_frio_rico_multipack.png"},

        // --- 14. VARIANTES DE TAMAÑO, SABOR Y PRESENTACIÓN (PERSONAL, 1L, 1.5L, 5KG, SIX-PACKS) ---
        {"7750106001102", "Inca Kola Sabor Original 1 Litro", "Inca Kola", "Gaseosas y Bebidas", "4.50", "3.60", "packshots/inka_kola.png"},
        {"7750106001119", "Inca Kola Sabor Original Lata 355ml", "Inca Kola", "Gaseosas y Bebidas", "2.80", "2.15", "packshots/inka_kola_500ml.png"},
        {"7750106002109", "Coca Cola Sabor Original 1 Litro", "Coca Cola", "Gaseosas y Bebidas", "4.50", "3.60", "packshots/coca_cola.png"},
        {"7750106002116", "Coca Cola Sabor Original Lata 355ml", "Coca Cola", "Gaseosas y Bebidas", "2.80", "2.15", "packshots/coca_cola_500ml.png"},
        {"7750182220385", "Gaseosa Fanta Naranja 1.5 Litros", "Fanta", "Gaseosas y Bebidas", "5.80", "4.60", "packshots/fanta.png"},
        {"7750182000338", "Gaseosa Sprite Lima Limón 1.5 Litros", "Sprite", "Gaseosas y Bebidas", "5.80", "4.60", "packshots/sprite.png"},
        {"775117011960",  "Agua Mineral San Mateo Con Gas 600ml", "San Mateo", "Gaseosas y Bebidas", "1.60", "1.15", "packshots/agua_san_mateo_600ml.png"},
        {"7750111006601", "Cerveza Pilsen Callao Six-Pack Latas 355ml", "Pilsen Callao", "Bebidas Alcohólicas", "23.50", "19.20", "packshots/cerveza_pilsen.png"},
        {"7750111006618", "Cerveza Cristal Six-Pack Latas 355ml", "Cristal", "Bebidas Alcohólicas", "22.50", "18.50", "packshots/cerveza_cristal_lata.png"},
        {"7750106006039", "Cerveza Cusqueña Dorada 620ml Retornable", "Cusqueña", "Bebidas Alcohólicas", "7.50", "6.00", "packshots/cerveza_cusquena_dorada.png"},
        {"750106419173",  "Cerveza Corona Extra Six-Pack Botella 355ml", "Corona", "Bebidas Alcohólicas", "34.00", "27.50", "packshots/cerveza_corona.png"},
        {"7750108003303", "Leche Gloria Azul Evaporada Chica 170g", "Gloria", "Lácteos y Derivados", "2.40", "1.95", "packshots/leche_gloria_azul.png"},
        {"7750108003310", "Leche Gloria Azul Evaporada Six-Pack x6 Latas 400g", "Gloria", "Lácteos y Derivados", "24.00", "21.00", "packshots/leche_gloria_azul.png"},
        {"7750108003327", "Yogur Gloria Fresa Botella Personal 185g", "Gloria", "Lácteos y Derivados", "2.20", "1.70", "packshots/yogur_gloria_fresa.png"},
        {"7750108003334", "Yogur Gloria Vainilla Botella Personal 185g", "Gloria", "Lácteos y Derivados", "2.20", "1.70", "packshots/yogur_gloria_vainilla.png"},
        {"7750108003341", "Yogur Gloria Durazno Botella 1 Litro", "Gloria", "Lácteos y Derivados", "6.20", "5.00", "packshots/yogur_gloria_vainilla_1kg.png"},
        {"7750115010301", "Galleta Casino Menta 68g", "Victoria", "Golosinas y Chocolates", "1.00", "0.75", "packshots/galleta_casino.png"},
        {"7750115010318", "Galleta Casino Chocolate 68g", "Victoria", "Golosinas y Chocolates", "1.00", "0.75", "packshots/galleta_casino.png"},
        {"7750115010325", "Galleta Tentación Vainilla 70g", "Victoria", "Golosinas y Chocolates", "1.00", "0.75", "packshots/galleta_tentacion.png"},
        {"7750115010332", "Galleta Oreo Original Paquete x4 (36g)", "Oreo", "Golosinas y Chocolates", "1.20", "0.90", "packshots/galleta_oreo.png"},
        {"7750115010349", "Pastillas Halls Menta Eucalipto", "Halls", "Golosinas y Chocolates", "1.00", "0.70", "packshots/halls_menta.png"},
        {"7750109004409", "Arroz Extra Costeño Bolsa 5kg Familiar", "Costeño", "Abarrotes y Despensa", "21.50", "18.20", "packshots/arroz_costeno.png"},
        {"7750109004416", "Arroz Superior Faraón Bolsa 5kg Familiar", "Faraón", "Abarrotes y Despensa", "20.50", "17.50", "packshots/arroz_faraon.png"},
        {"7750116011100", "Avena Precocida 3 Ositos Bolsa Familiar 500g", "3 Ositos", "Panadería y Desayuno", "3.80", "2.95", "packshots/avena_tres_ositos.png"},
        {"7750116011117", "Café Soluble Nescafé Tradición Doypack 50g", "Nescafé", "Panadería y Desayuno", "6.20", "4.90", "packshots/cafe_nescafe.png"},
        {"7750114009305", "Detergente Bolívar Blanco Activo Bolsa 450g", "Bolívar", "Limpieza y Cuidado del Hogar", "4.80", "3.80", "packshots/detergente_bolivar.png"},
        {"7750114009312", "Detergente Ace Limpieza Completa Bolsa 330g", "Ace", "Limpieza y Cuidado del Hogar", "3.80", "3.00", "packshots/detergente_ace.png"},
        {"7750114009329", "Lejía Clorox Tradicional Botella 680ml", "Clorox", "Limpieza y Cuidado del Hogar", "2.20", "1.70", "packshots/lejia_clorox.png"},
        {"7750107002108", "Hot Dog de Pollo San Fernando Económico 250g", "San Fernando", "Embutidos y Fiambrería", "3.20", "2.50", "packshots/hot_dog_pollo.png"},
        {"7750107002115", "Jamonada de Pollo San Fernando Económica 200g", "San Fernando", "Embutidos y Fiambrería", "3.50", "2.75", "packshots/jamonada_pollo.png"},

        // --- 15. EXPANSIÓN COMERCIAL OLA 3 (40 VARIANTES ZERO, PERSONALES, SACHETS, 5KG Y SIX-PACKS) ---
        {"7750106001126", "Inca Kola Sin Azúcar Zero 1.5 Litros", "Inca Kola", "Gaseosas y Bebidas", "6.50", "5.20", "packshots/inka_kola.png"},
        {"7750106001133", "Inca Kola Sin Azúcar Zero 3 Litros", "Inca Kola", "Gaseosas y Bebidas", "12.00", "9.80", "packshots/inka_kola_3l.png"},
        {"7750106002123", "Coca Cola Sin Azúcar Zero 1.5 Litros", "Coca Cola", "Gaseosas y Bebidas", "6.50", "5.20", "packshots/coca_cola.png"},
        {"7750106002130", "Coca Cola Sin Azúcar Zero 3 Litros", "Coca Cola", "Gaseosas y Bebidas", "12.00", "9.80", "packshots/coca_cola_3l.png"},
        {"7750106003038", "Agua San Luis Sin Gas 2.5 Litros", "San Luis", "Gaseosas y Bebidas", "3.50", "2.70", "packshots/agua_san_luis.png"},
        {"7750670010047", "Agua Cielo Sin Gas 2.5 Litros", "Cielo", "Gaseosas y Bebidas", "2.80", "2.15", "packshots/agua_cielo.png"},
        {"7750106008057", "Jugo Frugos del Valle Durazno Botella 300ml", "Frugos", "Gaseosas y Bebidas", "1.80", "1.35", "packshots/frugos_durazno.png"},
        {"7750106008064", "Jugo Frugos del Valle Mango Botella 300ml", "Frugos", "Gaseosas y Bebidas", "1.80", "1.35", "packshots/frugos_mango.png"},
        {"7750106006046", "Cerveza Cusqueña Trigo 620ml Retornable", "Cusqueña", "Bebidas Alcohólicas", "7.50", "6.00", "packshots/cerveza_cusquena.png"},
        {"7750106006053", "Cerveza Cusqueña Dorada Six-Pack Botella 310ml", "Cusqueña", "Bebidas Alcohólicas", "30.00", "24.50", "packshots/cerveza_cusquena_dorada.png"},
        {"7750111006625", "Cerveza Pilsen Callao Botella Personal 305ml", "Pilsen Callao", "Bebidas Alcohólicas", "4.00", "3.15", "packshots/cerveza_pilsen.png"},
        {"7891991000833", "Cerveza Stella Artois Six-Pack Botella 330ml", "Stella Artois", "Bebidas Alcohólicas", "36.00", "29.00", "packshots/cerveza_stella.png"},
        {"7750170000029", "Vino Tabernero Rose Semi Seco 750ml", "Tabernero", "Bebidas Alcohólicas", "21.00", "16.80", "packshots/vino_tabernero.png"},
        {"7758574005602", "Papas Fritas Lay's Clásicas Personal 42g", "Lay's", "Snacks y Piqueos", "2.00", "1.50", "packshots/lays_clasicas_140g.png"},
        {"7758574005619", "Papas Fritas Lay's Ondas Personal 42g", "Lay's", "Snacks y Piqueos", "2.00", "1.50", "packshots/lays_onduladas.png"},
        {"7758574005626", "Chizitos Queso Personal 44g", "Frito-Lay", "Snacks y Piqueos", "1.50", "1.10", "packshots/chizitos_queso.png"},
        {"7750670010856", "Cuates Picantes Personal 43g", "Karinto", "Snacks y Piqueos", "1.00", "0.75", "packshots/cuates_picantes_100g.png"},
        {"7750670010863", "Maní Salado Karinto Personal 45g", "Karinto", "Snacks y Piqueos", "1.00", "0.75", "packshots/mani_karinto.png"},
        {"7750670010924", "Papas Artesanales Inka Chips Sal Marina Personal 42g", "Inka Chips", "Snacks y Piqueos", "2.50", "1.90", "packshots/inka_chips_sal_marina.png"},
        {"7750108003358", "Leche Gloria Roja Entera Chica 170g", "Gloria", "Lácteos y Derivados", "2.40", "1.95", "packshots/leche_gloria_roja.png"},
        {"7750108003365", "Leche Gloria Light Chica 170g", "Gloria", "Lácteos y Derivados", "2.40", "1.95", "packshots/leche_gloria_light.png"},
        {"7750108003372", "Leche Chocolatada Gloria Cajita Personal 200ml", "Gloria", "Lácteos y Derivados", "1.80", "1.35", "packshots/leche_chocolatada_gloria.png"},
        {"7750108003389", "Margarina Manty Barra 90g", "Manty", "Lácteos y Derivados", "1.80", "1.35", "packshots/margarina_manty.png"},
        {"7750108003396", "Huevos Pardos La Calera Bandeja x30 unidades", "La Calera", "Lácteos y Derivados", "18.00", "15.00", "packshots/huevos_la_calera_x15.png"},
        {"7750109004423", "Aceite Vegetal Primor Clásico Botella 500ml", "Primor", "Abarrotes y Despensa", "5.00", "4.10", "packshots/aceite_primor.png"},
        {"7750109004430", "Aceite Vegetal Cocinero Botella 500ml", "Cocinero", "Abarrotes y Despensa", "4.50", "3.70", "packshots/aceite_cocinero.png"},
        {"7750109004447", "Azúcar Rubia Paramonga Bolsa 5kg Familiar", "Paramonga", "Abarrotes y Despensa", "19.00", "16.00", "packshots/azucar_paramonga.png"},
        {"7750109004454", "Sopa Instantánea Ajinomen Carne 80g", "Ajinomoto", "Abarrotes y Despensa", "2.00", "1.50", "packshots/ajinomen_pollo.png"},
        {"7750243030427", "Ketchup AlaCena Sachet 100g", "AlaCena", "Abarrotes y Despensa", "2.00", "1.50", "packshots/ketchup_alacena_380g.png"},
        {"7750109004461", "Sillao Kikko Clásico Botella 160ml", "Kikko", "Abarrotes y Despensa", "2.00", "1.50", "packshots/sillao_kikko_500ml.png"},
        {"7613036615549", "Bebida Achocolatada Milo Nestlé Doypack 180g", "Nestlé", "Panadería y Desayuno", "8.50", "6.80", "packshots/milo_nestle_400g.png"},
        {"7613036615556", "Chocolate Sublime Blanco 30g", "Nestlé", "Golosinas y Chocolates", "2.00", "1.50", "packshots/chocolate_sublime.png"},
        {"7750115010356", "Galleta Casino Lúcuma 68g", "Victoria", "Golosinas y Chocolates", "1.00", "0.75", "packshots/galleta_casino.png"},
        {"7750115010363", "Galleta Tentación Naranja 70g", "Victoria", "Golosinas y Chocolates", "1.00", "0.75", "packshots/galleta_tentacion.png"},
        {"7750116011124", "Mermelada de Fresa Gloria Sachet 100g", "Gloria", "Panadería y Desayuno", "1.80", "1.35", "packshots/mermelada_gloria.png"},
        {"7750114009336", "Detergente Opal Ultra Bolsa 330g", "Opal", "Limpieza y Cuidado del Hogar", "3.80", "3.00", "packshots/detergente_opal.png"},
        {"7750114009343", "Suavizante Suavitel Fresca Primavera Sachet 200ml", "Suavitel", "Limpieza y Cuidado del Hogar", "2.00", "1.50", "packshots/suavizante_suavitel.png"},
        {"7750114009350", "Limpiador Multiusos Poett Lavanda Botella 450ml", "Poett", "Limpieza y Cuidado del Hogar", "2.80", "2.15", "packshots/limpiador_poett.png"},
        {"7750113008209", "Papel Higiénico Elite Dúo Doble Hoja x2 rollos", "Elite", "Cuidado Personal y Dental", "3.20", "2.50", "packshots/papel_higienico_elite.png"},
        {"7750107002122", "Queso Fresco Bonlé Gloria Tajado 200g", "Gloria", "Embutidos y Fiambrería", "5.20", "4.10", "packshots/queso_fresco_bonle.png"},

        // --- 16. EXPANSIÓN COMERCIAL OLA 4: MASCOTAS (PERROS Y GATOS) + MENESTRAS Y BODEGA ---
        // Comida para Perros (seco, paté en lata y sobres húmedos)
        {"7753176005159", "Comida para Perro Ricocan Adulto Raza Pequeña Cordero 1kg", "Ricocan", "Mascotas y Alimento", "11.50", "9.20", "packshots/ricocan_cordero_1kg.png"},
        {"7753176001434", "Comida para Perro Ricocan Adulto Multisabores 1kg", "Ricocan", "Mascotas y Alimento", "11.50", "9.20", "packshots/ricocan_adulto_multi_1kg.png"},
        {"7753176004107", "Comida para Perro Ricocan Cachorros Carne y Leche 1kg", "Ricocan", "Mascotas y Alimento", "11.90", "9.50", "packshots/ricocan_cachorro_1kg.png"},
        {"7753176005104", "Paté para Perro Ricocan Adulto Cordero Lata 330g", "Ricocan", "Mascotas y Alimento", "5.50", "4.30", "packshots/ricocan_pate_cordero_330g.png"},
        {"7753176000567", "Paté para Perro Ricocan Cachorro Lata 330g", "Ricocan", "Mascotas y Alimento", "5.50", "4.30", "packshots/ricocan_pate_cachorro_330g.png"},
        {"7753176003049", "Sobre Ricocan Trocitos en Salsa Cordero 100g", "Ricocan", "Mascotas y Alimento", "3.80", "2.95", "packshots/ricocan_sobre_cordero_100g.png"},
        {"7750885026376", "Comida para Perro Mimaskot Adulto Carne 1kg", "Mimaskot", "Mascotas y Alimento", "12.50", "10.00", "packshots/mimaskot_adulto_carne_1kg.png"},
        {"7750885026345", "Comida para Perro Mimaskot Adulto Carne Bolsa 3kg", "Mimaskot", "Mascotas y Alimento", "29.90", "24.50", "packshots/mimaskot_adulto_carne_3kg.png"},
        {"7750885026512", "Comida para Perro Mimaskot Cachorros 1kg", "Mimaskot", "Mascotas y Alimento", "12.50", "10.00", "packshots/mimaskot_cachorro_1kg.png"},
        {"7613287613356", "Comida para Perro Dogui Adultos Todas las Razas 1.5kg", "Dogui", "Mascotas y Alimento", "17.50", "14.20", "packshots/dogui_adulto_1_5kg.png"},
        {"2050044506523", "Tripack Sobre Dog Chow Adultos Carne 3x100g", "Dog Chow", "Mascotas y Alimento", "13.50", "10.80", "packshots/dog_chow_sobre_carne_100g.png"},
        {"7896029004326", "Sobre Pedigree Adulto Carne en Salsa 100g", "Pedigree", "Mascotas y Alimento", "3.50", "2.70", "packshots/pedigree_sobre_carne_100g.png"},
        {"7896029004357", "Sobre Pedigree Adulto Pollo en Salsa 100g", "Pedigree", "Mascotas y Alimento", "3.50", "2.70", "packshots/pedigree_sobre_pollo_100g.png"},
        {"23100051048",   "Comida para Perro Pedigree Adulto Carne Bolsa 2kg", "Pedigree", "Mascotas y Alimento", "34.00", "27.80", "packshots/pedigree_adulto_2kg.png"},
        // Comida para Gatos (complemento esencial de mascotas)
        {"7753176005548", "Comida para Gato Ricocat Adulto Atún y Sardina 1kg", "Ricocat", "Mascotas y Alimento", "14.00", "11.20", "packshots/ricocat_adulto_1kg.png"},
        {"7753176007337", "Paté para Gato Ricocat Adulto Lata 180g", "Ricocat", "Mascotas y Alimento", "4.50", "3.50", "packshots/ricocat_pate_180g.png"},
        {"7753176003100", "Sobre Ricocat Trozos Salmón en Salsa 85g", "Ricocat", "Mascotas y Alimento", "3.80", "2.95", "packshots/ricocat_sobre_salmon_85g.png"},
        // Bodega Peruana: Menestras, Galletas, Despensa y Hogar con fotos oficiales reales
        {"7622201714819", "Galletas Soda Field Clásica Six-Pack x6", "Field", "Panadería y Desayuno", "3.50", "2.75", "packshots/galleta_soda_field_x6.png"},
        {"7622202232756", "Galletas Saladas Ritz Clásica 70g", "Ritz", "Snacks y Piqueos", "2.00", "1.50", "packshots/galleta_ritz_70g.png"},
        {"7613035803138", "Galletas Morochas Nestlé Six-Pack x6", "Nestlé", "Golosinas y Chocolates", "4.80", "3.80", "packshots/galleta_morochas_x6.png"},
        {"38000184888",   "Papas Pringles Original Lata 104g", "Pringles", "Snacks y Piqueos", "9.50", "7.50", "packshots/pringles_original_104g.png"},
        {"7750243049566", "Mostaza AlaCena Doypack 220g", "AlaCena", "Abarrotes y Despensa", "4.80", "3.80", "packshots/mostaza_alacena.png"},
        {"7753121001892", "Vinagre Tinto Venturo Botella 600ml", "Venturo", "Abarrotes y Despensa", "5.00", "3.90", "packshots/vinagre_tinto_venturo_600ml.png"},
        {"7758003000161", "Lenteja Costeño Bolsa 500g", "Costeño", "Abarrotes y Despensa", "5.20", "4.10", "packshots/lenteja_costeno_500g.png"},
        {"7755139542183", "Frijol Canario Costeño Bolsa 500g", "Costeño", "Abarrotes y Despensa", "7.80", "6.30", "packshots/frijol_canario_costeno_500g.png"},
        {"7758003087193", "Arveja Partida Costeño Bolsa 500g", "Costeño", "Abarrotes y Despensa", "3.80", "2.95", "packshots/arveja_partida_costeno_500g.png"},
        {"7758003370110", "Garbanzo Costeño Bolsa 500g", "Costeño", "Abarrotes y Despensa", "6.20", "4.95", "packshots/garbanzo_costeno_500g.png"},
        {"7750243227247", "Harina Preparada Blanca Flor Bolsa 1kg", "Blanca Flor", "Abarrotes y Despensa", "7.50", "6.00", "packshots/harina_blanca_flor_1kg.png"},
        {"7613030498698", "Manjar Blanco Nestlé Doypack 200g", "Nestlé", "Panadería y Desayuno", "4.80", "3.80", "packshots/manjar_nestle_200g.png"},
        {"7750151009614", "Yogur Frutado Laive Fresa Botella 800g", "Laive", "Lácteos y Derivados", "8.50", "6.80", "packshots/yogur_laive_fresa_800g.png"},
        {"8445291642126", "Mini Panetón D'Onofrio Bolsa 80g", "D'Onofrio", "Panadería y Desayuno", "4.20", "3.30", "packshots/mini_paneton_donofrio_80g.png"},
        {"7501032938215", "Ambientador Glade Aerosol Campos de Lavanda 400ml", "Glade", "Limpieza y Cuidado del Hogar", "11.50", "9.20", "packshots/ambientador_glade_lavanda.png"},

        // --- 17. EXPANSIÓN COMERCIAL OLA 5 (PAÑALES/BEBÉ, CAFÉ, CONDIMENTOS, HOGAR Y MASCOTAS) ---
        {"7751493010139", "Pañales Huggies Natural Care Talla G x66", "Huggies", "Cuidado Personal y Dental", "59.90", "49.00", "packshots/panales_huggies_g.png"},
        {"7759185011327", "Pañales Babysec Super Premium Talla G x66", "Babysec", "Cuidado Personal y Dental", "51.90", "42.50", "packshots/panales_babysec_g.png"},
        {"7702031291565", "Shampoo Original Johnson's Baby 200ml", "Johnson's", "Cuidado Personal y Dental", "19.50", "15.80", "packshots/shampoo_johnsons_baby.png"},
        {"7702010921681", "Jabón Protex Antibacterial Avena Pack x6", "Protex", "Cuidado Personal y Dental", "21.50", "17.50", "packshots/jabon_protex_avena_x6.png"},
        {"7500435116800", "Máquina de Afeitar Gillette Prestobarba 3", "Gillette", "Cuidado Personal y Dental", "21.50", "17.20", "packshots/gillette_prestobarba3.png"},
        {"7506306237315", "Shampoo Sedal Ceramidas 340ml", "Sedal", "Cuidado Personal y Dental", "12.50", "10.00", "packshots/shampoo_sedal_ceramidas.png"},
        {"7702035800664", "Enjuague Bucal Listerine Cool Mint 180ml", "Listerine", "Cuidado Personal y Dental", "9.90", "7.90", "packshots/listerine_cool_mint.png"},
        {"7804653341656", "Papel Toalla Doble Hoja Gigante", "Home Care", "Cuidado Personal y Dental", "9.50", "7.60", "packshots/papel_toalla_gigante.png"},
        {"7750463001733", "Café Molido Altomayo Clásico 450g", "Altomayo", "Panadería y Desayuno", "29.90", "24.50", "packshots/cafe_altomayo_450g.png"},
        {"7752087129305", "Café Instantáneo Kirma Clásico 180g", "Kirma", "Panadería y Desayuno", "23.90", "19.50", "packshots/cafe_kirma_180g.png"},
        {"8445292127240", "Cebada Instantánea Ecco 170g", "Ecco", "Panadería y Desayuno", "14.50", "11.80", "packshots/cebada_ecco_170g.png"},
        {"7752748011963", "Cocoa Winter's Lata 360g", "Winter's", "Panadería y Desayuno", "33.90", "27.80", "packshots/cocoa_winters_360g.png"},
        {"7758574004605", "Avena Quaker Tradicional Bolsa 200g", "Quaker", "Panadería y Desayuno", "4.50", "3.50", "packshots/avena_quaker_200g.png"},
        {"7759826001670", "Cereal Ángel Flakes Bolsa 1kg", "Ángel", "Panadería y Desayuno", "15.50", "12.60", "packshots/cereal_angel_flakes_1kg.png"},
        {"2050000442971", "Mermelada Fanny Fresa Pote 700g", "Fanny", "Panadería y Desayuno", "12.50", "10.00", "packshots/mermelada_fanny_700g.png"},
        {"7751271031653", "Mantequilla con Sal Gloria Barra 90g", "Gloria", "Lácteos y Derivados", "6.50", "5.20", "packshots/mantequilla_gloria_90g.png"},
        {"7750477080007", "Té Canela y Clavo McColin's Caja x100", "McColin's", "Panadería y Desayuno", "11.50", "9.20", "packshots/te_mccolins_canela_clavo.png"},
        {"7754487000000", "Sazonador Ajinomoto Frasco 100g", "Ajinomoto", "Abarrotes y Despensa", "10.50", "8.40", "packshots/ajinomoto_sazonador_100g.png"},
        {"7754487000345", "Caldo Doña Gusta Gallina Pack x6", "Doña Gusta", "Abarrotes y Despensa", "2.50", "1.90", "packshots/dona_gusta_gallina_x6.png"},
        {"7754487000352", "Caldo Doña Gusta Carne Pack x6", "Doña Gusta", "Abarrotes y Despensa", "2.50", "1.90", "packshots/dona_gusta_carne_x6.png"},
        {"7753121000383", "Pimienta Negra Molida Sibarita 40g", "Sibarita", "Abarrotes y Despensa", "9.90", "7.90", "packshots/sibarita_pimienta_40g.png"},
        {"7753121004015", "Comino Molido Sibarita Pack x6 Sobres", "Sibarita", "Abarrotes y Despensa", "4.20", "3.30", "packshots/sibarita_comino_x6.png"},
        {"7753121003855", "Palillo Sibarita Sobre 57g", "Sibarita", "Abarrotes y Despensa", "2.50", "1.90", "packshots/sibarita_palillo_57g.png"},
        {"7750885003469", "Salsa de Tomate Pomarola Doypack 145g", "Pomarola", "Abarrotes y Despensa", "1.80", "1.35", "packshots/salsa_pomarola_145g.png"},
        {"7751158187893", "Duraznos en Almíbar Aconcagua Lata 820g", "Aconcagua", "Abarrotes y Despensa", "9.50", "7.60", "packshots/duraznos_aconcagua_820g.png"},
        {"7755139002816", "Arroz Superior Paisana Bolsa 1kg", "Paisana", "Abarrotes y Despensa", "4.50", "3.70", "packshots/arroz_paisana_1kg.png"},
        {"2050044298305", "Twopack Aceite Vegetal Primor Clásico 2x900ml", "Primor", "Abarrotes y Despensa", "17.50", "14.50", "packshots/aceite_primor_twopack.png"},
        {"7750243057448", "Jabón para Ropa Bolívar Limón 190g", "Bolívar", "Limpieza y Cuidado del Hogar", "3.20", "2.50", "packshots/jabon_bolivar_limon_190g.png"},
        {"7706800766513", "Insecticida Raid Aerosol Acción Total", "Raid", "Limpieza y Cuidado del Hogar", "18.50", "15.00", "packshots/insecticida_raid_aerosol.png"},
        {"7751851008167", "Desinfectante Limpiador Sapolio Pino Galón 3.78L", "Sapolio", "Limpieza y Cuidado del Hogar", "24.50", "19.80", "packshots/desinfectante_sapolio_pino.png"},
        {"7750243079136", "Detergente Marsella Amazonía Tropical 4kg", "Marsella", "Limpieza y Cuidado del Hogar", "32.90", "27.00", "packshots/detergente_marsella_4kg.png"},
        {"7613287613455", "Comida para Perro Dogui Adulto Saco 8kg", "Dogui", "Mascotas y Alimento", "68.00", "56.00", "packshots/dogui_adulto_8kg.png"},
        {"7896029022252", "Sobre Pedigree Cachorro Pollo en Salsa 100g", "Pedigree", "Mascotas y Alimento", "3.80", "2.95", "packshots/pedigree_cachorro_pollo_100g.png"},
        {"7896029046609", "Sobre Whiskas Gato Adulto Carne 85g", "Whiskas", "Mascotas y Alimento", "3.50", "2.70", "packshots/whiskas_sobre_carne_85g.png"},
        {"7891000120781", "Sobre Purina Felix Gato Adulto Atún 85g", "Felix", "Mascotas y Alimento", "4.20", "3.30", "packshots/felix_sobre_atun_85g.png"},

        // --- 18. EXPANSIÓN COMERCIAL OLA 6 (40 PRODUCTOS: LICORES, ENERGIZANTES, BOTIQUÍN, PILAS Y GOLOSINAS) ---
        {"7750533001083", "Pisco Puro Quebranta Tabernero 700ml", "Tabernero", "Bebidas Alcohólicas", "41.90", "34.50", "packshots/pisco_tabernero_quebranta_700ml.png"},
        {"7758218000024", "Pisco Santiago Queirolo Acholado 750ml", "Santiago Queirolo", "Bebidas Alcohólicas", "28.90", "23.50", "packshots/pisco_queirolo_acholado_750ml.png"},
        {"7751738445672", "Ron Cartavio Black Botella 1 Litro", "Cartavio", "Bebidas Alcohólicas", "29.90", "24.50", "packshots/ron_cartavio_black_1l.png"},
        {"26964861006", "Ron Flor de Caña Spresso 750ml", "Flor de Caña", "Bebidas Alcohólicas", "46.90", "38.50", "packshots/ron_flor_de_cana_spresso_750ml.png"},
        {"7758218000161", "Vino Santiago Queirolo Borgoña Pack x2 750ml", "Santiago Queirolo", "Bebidas Alcohólicas", "28.90", "23.50", "packshots/vino_queirolo_borgona_x2.png"},
        {"7804340901057", "Vino Tinto Carménère Tarapacá Gran Reserva 750ml", "Tarapacá", "Bebidas Alcohólicas", "58.90", "48.00", "packshots/vino_tarapaca_gran_reserva.png"},
        {"7753749003339", "Cerveza Cusqueña Trigo Lata 355ml", "Cusqueña", "Bebidas Alcohólicas", "5.00", "3.90", "packshots/cerveza_cusquena_trigo_lata.png"},
        {"7753749003353", "Cerveza Cusqueña Negra Lata 355ml", "Cusqueña", "Bebidas Alcohólicas", "5.00", "3.90", "packshots/cerveza_cusquena_negra_lata.png"},
        {"7750670012270", "Cerveza Tres Cruces Six-Pack Latas 355ml", "Tres Cruces", "Bebidas Alcohólicas", "20.90", "17.00", "packshots/cerveza_tres_cruces_sixpack.png"},
        {"7753749008396", "Cerveza Budweiser Six-Pack Latas 355ml", "Budweiser", "Bebidas Alcohólicas", "19.90", "16.20", "packshots/cerveza_budweiser_sixpack.png"},
        {"7753749009072", "Cerveza Pilsen Callao Fresh Botella 305ml", "Pilsen Callao", "Bebidas Alcohólicas", "4.00", "3.15", "packshots/cerveza_pilsen_fresh_305ml.png"},
        {"849806005860", "Bebida Alcohólica Four Loko Purple Lata 591ml", "Four Loko", "Bebidas Alcohólicas", "13.50", "10.80", "packshots/four_loko_purple_591ml.png"},
        {"7755321001481", "Chilcano Portón Mango Lata 355ml", "Portón", "Bebidas Alcohólicas", "7.90", "6.20", "packshots/porton_chilcano_mango_355ml.png"},
        {"9002490100094", "Bebida Energizante Red Bull Lata 250ml", "Red Bull", "Gaseosas y Bebidas", "7.50", "5.90", "packshots/red_bull_250ml.png"},
        {"70847038672", "Bebida Energizante Monster Mango Loco Lata 473ml", "Monster Energy", "Gaseosas y Bebidas", "8.00", "6.30", "packshots/monster_mango_loco_473ml.png"},
        {"7751655000602", "Bebida Rehidratante Gatorade Mandarina 500ml", "Gatorade", "Gaseosas y Bebidas", "2.80", "2.15", "packshots/gatorade_mandarina_500ml.png"},
        {"7750670012478", "Té Helado Free Tea Durazno 500ml", "Free Tea", "Gaseosas y Bebidas", "2.80", "2.15", "packshots/free_tea_durazno_500ml.png"},
        {"7750670012164", "Té Helado Free Tea Limón 450ml", "Free Tea", "Gaseosas y Bebidas", "2.80", "2.15", "packshots/free_tea_limon_450ml.png"},
        {"2050044370162", "Bebida de Durazno Pulp Botella 1.5 Litros", "Pulp", "Gaseosas y Bebidas", "5.50", "4.30", "packshots/pulp_durazno_15l.png"},
        {"7751271038515", "Bebida de Frutas Tampico Citrus Punch 600ml", "Tampico", "Gaseosas y Bebidas", "3.20", "2.45", "packshots/tampico_citrus_600ml.png"},
        {"7750182002196", "Gaseosa Schweppes Ginger Ale 1.5 Litros", "Schweppes", "Gaseosas y Bebidas", "6.50", "5.10", "packshots/schweppes_ginger_ale_15l.png"},
        {"7702026174064", "Toallas Higiénicas Nosotras Invisible x30", "Nosotras", "Cuidado Personal y Dental", "10.50", "8.30", "packshots/toallas_nosotras_invisible_x30.png"},
        {"7751493009867", "Toallas Higiénicas Kotex Nocturna Discreta x12", "Kotex", "Cuidado Personal y Dental", "11.50", "9.10", "packshots/toallas_kotex_nocturna_x12.png"},
        {"7506306247093", "Desodorante Dove Original Aerosol 250ml", "Dove", "Cuidado Personal y Dental", "22.90", "18.50", "packshots/desodorante_dove_aerosol_250ml.png"},
        {"4006000129402", "Crema Corporal Nivea Regeneración Intensiva 400ml", "Nivea", "Cuidado Personal y Dental", "39.90", "32.50", "packshots/crema_nivea_regeneracion_400ml.png"},
        {"7759185012362", "Papel Higiénico Elite Resistente XL Pack x12", "Elite", "Cuidado Personal y Dental", "20.50", "16.50", "packshots/papel_higienico_elite_xl_x12.png"},
        {"7757310009188", "Alcohol Medicinal 70° Hersil Botella 1 Litro", "Hersil", "Cuidado Personal y Dental", "12.00", "9.50", "packshots/alcohol_medicinal_hersil_1l.png"},
        {"7750215091647", "Agua Oxigenada Portugal 10V Botella 1 Litro", "Portugal", "Cuidado Personal y Dental", "6.90", "5.40", "packshots/agua_oxigenada_portugal_1l.png"},
        {"7751370000086", "Algodón Hidrófilo en Zig Zag Family Care 100g", "Family Care", "Cuidado Personal y Dental", "6.20", "4.80", "packshots/algodon_hidrofilo_100g.png"},
        {"7702003469305", "Curitas Transpiel Caja x20 unidades", "Curitas", "Cuidado Personal y Dental", "11.50", "9.00", "packshots/curitas_transpiel_x20.png"},
        {"41333588640", "Pilas Alcalinas Duracell AA Pack x8", "Duracell", "Limpieza y Cuidado del Hogar", "25.90", "20.80", "packshots/pilas_duracell_aa_x8.png"},
        {"41333424019", "Pilas Alcalinas Duracell AAA Pack x4", "Duracell", "Limpieza y Cuidado del Hogar", "15.50", "12.40", "packshots/pilas_duracell_aaa_x4.png"},
        {"7506105616076", "Chicle Trident Freshmint Botella x18", "Trident", "Golosinas y Chocolates", "4.70", "3.65", "packshots/chicle_trident_freshmint_x18.png"},
        {"7613031328536", "Beso de Moza Vainilla Nestlé Caja x20", "Nestlé", "Golosinas y Chocolates", "24.50", "19.80", "packshots/beso_de_moza_caja_x20.png"},
        {"7758102004947", "Chupete Globo Pop Surtido Bolsa x24", "Globo Pop", "Golosinas y Chocolates", "8.20", "6.40", "packshots/chupete_globo_pop_x24.png"},
        {"7750885024860", "Chocolate con Almendras Vizzio Costa 19.2g", "Costa", "Golosinas y Chocolates", "1.70", "1.25", "packshots/chocolate_vizzio_costa.png"},
        {"7750243031318", "Galletas Glacitas Toffee Six-Pack", "Victoria", "Golosinas y Chocolates", "4.20", "3.30", "packshots/galleta_glacitas_toffee_x6.png"},
        {"7750243077484", "Galletas Tentación Chocolate Six-Pack", "Victoria", "Golosinas y Chocolates", "4.90", "3.85", "packshots/galleta_tentacion_choc_x6.png"},
        {"7750885434645", "Wafers Nik Costa Chocolate Pack x6", "Costa", "Golosinas y Chocolates", "3.50", "2.75", "packshots/wafer_nik_chocolate_x6.png"},
        {"7750885003681", "Caramelos Ambrosoli Cocoroko Limón Bolsa 350g", "Ambrosoli", "Golosinas y Chocolates", "8.50", "6.70", "packshots/caramelos_ambrosoli_limon_350g.png"},

        // --- 19. EXPANSIÓN COMERCIAL OLA 7 (43 PRODUCTOS: CONGELADOS, EMBUTIDOS, QUESOS, PASTAS, POSTRES Y HOGAR) ---
        {"7750946007566", "Nuggets de Pollo San Fernando Safari x10", "San Fernando", "Helados y Congelados", "5.90", "4.70", "packshots/nuggets_san_fernando_x10.png"},
        {"7550946003636", "Hamburguesa San Fernando La Casera x14", "San Fernando", "Helados y Congelados", "14.50", "11.80", "packshots/hamburguesa_san_fernando_x14.png"},
        {"7752346006392", "Mini Hamburguesa Parrillera Otto Kunz 600g", "Otto Kunz", "Helados y Congelados", "32.90", "26.80", "packshots/hamburguesa_otto_kunz_600g.png"},
        {"8711571093385", "Papas Prefritas Lamb Weston Original 750g", "Lamb Weston", "Helados y Congelados", "14.50", "11.60", "packshots/papas_prefritas_750g.png"},
        {"614143278426", "Tequeños Rellenos de Queso Teque Cheese x12", "Teque Cheese", "Helados y Congelados", "20.90", "16.80", "packshots/tequenos_queso_x12.png"},
        {"7613036713566", "Helado Peziduri Lúcuma D'Onofrio 900ml", "D'Onofrio", "Helados y Congelados", "11.90", "9.50", "packshots/helado_peziduri_lucuma_900ml.png"},
        {"7752087232111", "Helado Peziduri Chocolate D'Onofrio 900ml", "D'Onofrio", "Helados y Congelados", "11.90", "9.50", "packshots/helado_peziduri_chocolate_900ml.png"},
        {"7752346005098", "Jamón Inglés Braedt Paquete 200g", "Braedt", "Embutidos y Fiambrería", "16.50", "13.40", "packshots/jamon_ingles_braedt_200g.png"},
        {"7750302725066", "Jamón Inglés Otto Kunz Paquete 200g", "Otto Kunz", "Embutidos y Fiambrería", "13.90", "11.20", "packshots/jamon_ingles_otto_kunz_200g.png"},
        {"7752346008792", "Salchicha Frankfurter Alemán Otto Kunz 280g", "Otto Kunz", "Embutidos y Fiambrería", "18.90", "15.20", "packshots/salchicha_frankfurt_otto_280g.png"},
        {"7752346008563", "Cabanossi Otto Kunz Unidad", "Otto Kunz", "Embutidos y Fiambrería", "3.90", "3.00", "packshots/cabanossi_otto_kunz.png"},
        {"7622201426170", "Queso Crema Philadelphia Original 150g", "Kraft", "Lácteos y Derivados", "12.90", "10.40", "packshots/queso_philadelphia_150g.png"},
        {"7751271009706", "Queso Edam Bonlé Tajado 185g", "Bonlé", "Lácteos y Derivados", "13.20", "10.60", "packshots/queso_edam_bonle_185g.png"},
        {"7751271036290", "Leche Entera UHT Gloria Caja 946ml", "Gloria", "Lácteos y Derivados", "6.20", "5.10", "packshots/leche_gloria_uht_946ml.png"},
        {"7750151008945", "Leche Concentrada Sin Lactosa Laive Botella 400g", "Laive", "Lácteos y Derivados", "4.80", "3.95", "packshots/leche_laive_sin_lactosa_400g.png"},
        {"7613036500715", "Crema de Leche Nestlé Lata 300g", "Nestlé", "Lácteos y Derivados", "10.50", "8.50", "packshots/crema_leche_nestle_300g.png"},
        {"7751271038683", "Crema de Leche Gloria Caja 946ml", "Gloria", "Lácteos y Derivados", "28.50", "23.20", "packshots/crema_leche_gloria_946ml.png"},
        {"7751271037846", "Yogur Griego Gloria Mango 800g", "Gloria", "Lácteos y Derivados", "8.20", "6.60", "packshots/yogur_gloria_griego_mango_800g.png"},
        {"7750243082341", "Fideos Codo Rayado Don Vittorio 225g", "Don Vittorio", "Abarrotes y Despensa", "2.10", "1.65", "packshots/fideos_don_vittorio_codo_225g.png"},
        {"7750243082365", "Fideos Tornillo Don Vittorio 250g", "Don Vittorio", "Abarrotes y Despensa", "2.10", "1.65", "packshots/fideos_don_vittorio_tornillo_250g.png"},
        {"7750243017329", "Fideos Cabello de Ángel Don Vittorio 250g", "Don Vittorio", "Abarrotes y Despensa", "1.80", "1.40", "packshots/fideos_cabello_angel_250g.png"},
        {"7750885289016", "Fideos Tornillo Tricolor Molitalia 235g", "Molitalia", "Abarrotes y Despensa", "2.00", "1.55", "packshots/fideos_molitalia_tricolor_235g.png"},
        {"7754725057223", "Arroz Gran Reserva Extra Valle Norte 750g", "Valle Norte", "Abarrotes y Despensa", "4.30", "3.55", "packshots/arroz_valle_norte_750g.png"},
        {"7758003370127", "Maíz Pop Corn Costeño Bolsa 500g", "Costeño", "Abarrotes y Despensa", "3.40", "2.65", "packshots/maiz_pop_corn_costeno_500g.png"},
        {"7755139054594", "Quinua Costeño Bolsa 500g", "Costeño", "Abarrotes y Despensa", "8.90", "7.20", "packshots/quinua_costeno_500g.png"},
        {"7752414000314", "Aceite de Oliva Extra Virgen El Olivar 500ml", "El Olivar", "Abarrotes y Despensa", "34.50", "28.00", "packshots/aceite_oliva_el_olivar_500ml.png"},
        {"7758651000216", "Vinagre Blanco Venturo Botella 600ml", "Venturo", "Abarrotes y Despensa", "5.50", "4.30", "packshots/vinagre_blanco_venturo_600ml.png"},
        {"2050000002311", "Salsa de Ostión Panda Lee Kum Kee 510g", "Lee Kum Kee", "Abarrotes y Despensa", "27.90", "22.50", "packshots/salsa_ostion_panda_510g.png"},
        {"88169093767", "Sopa Criolla Maggi Gallina con Fideos 60g", "Maggi", "Abarrotes y Despensa", "3.90", "3.05", "packshots/sopa_maggi_criolla_60g.png"},
        {"7752230004428", "Gelatina Universal Fresa Sobre 130g", "Universal", "Abarrotes y Despensa", "4.20", "3.30", "packshots/gelatina_universal_fresa_130g.png"},
        {"7622201500276", "Flan en Polvo Royal Vainilla 80g", "Royal", "Abarrotes y Despensa", "3.90", "3.05", "packshots/flan_royal_vainilla_80g.png"},
        {"7622210091505", "Mazamorra Morada en Polvo Royal 140g", "Royal", "Abarrotes y Despensa", "4.50", "3.55", "packshots/mazamorra_morada_royal_140g.png"},
        {"7622300051822", "Polvo para Hornear Royal Sobre 20g", "Royal", "Abarrotes y Despensa", "1.50", "1.10", "packshots/polvo_hornear_royal_20g.png"},
        {"7750243069922", "Esencia de Vainilla Umsha Frasco 90ml", "Umsha", "Abarrotes y Despensa", "2.50", "1.90", "packshots/esencia_vainilla_umsha_90ml.png"},
        {"7750727116074", "Pan para Hamburguesa Bimbo Bolsa x8", "Bimbo", "Panadería y Desayuno", "9.50", "7.60", "packshots/pan_hamburguesa_bimbo_x8.png"},
        {"7750727005026", "Pan para Hot Dog Bimbo Bolsa x8", "Bimbo", "Panadería y Desayuno", "9.50", "7.60", "packshots/pan_hotdog_bimbo_x8.png"},
        {"7750727000298", "Tostadas Clásicas Bimbo Paquete x10", "Bimbo", "Panadería y Desayuno", "8.20", "6.50", "packshots/tostadas_bimbo_x10.png"},
        {"38000184895", "Papas Pringles Crema y Cebolla 109g", "Pringles", "Snacks y Piqueos", "9.40", "7.50", "packshots/pringles_crema_cebolla_109g.png"},
        {"38000183669", "Papas Pringles Sabor BBQ 158g", "Pringles", "Snacks y Piqueos", "14.90", "12.00", "packshots/pringles_bbq_158g.png"},
        {"7806500221128", "Servilletas Elite Premium Cóctel x50", "Elite", "Limpieza y Cuidado del Hogar", "4.90", "3.85", "packshots/servilletas_elite_coctel_x50.png"},
        {"7898553454851", "Papel Aluminio Darnel 45cm x 7.5m", "Darnel", "Limpieza y Cuidado del Hogar", "11.90", "9.50", "packshots/papel_aluminio_darnel.png"},
        {"51111027790", "Guantes Multiuso Scotch-Brite Talla M", "Scotch-Brite", "Limpieza y Cuidado del Hogar", "16.50", "13.20", "packshots/guantes_scotch_brite_m.png"},
        {"2050000299698", "Limpiavidrios Sapolio Aroma Lavanda 650ml", "Sapolio", "Limpieza y Cuidado del Hogar", "11.90", "9.50", "packshots/limpiavidrios_sapolio_650ml.png"}
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
