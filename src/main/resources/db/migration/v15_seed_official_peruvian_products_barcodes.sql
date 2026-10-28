-- ==========================================================================
-- MIGRACIÓN v15: SIEMBRA DE CATÁLOGO MAESTRO COMERCIAL PERUANO CON
-- CÓDIGOS DE BARRAS OFICIALES (EAN-13), PACKSHOTS E INTEGRIDAD MULTI-TENANT
-- ==========================================================================

-- 1. Asegurar categorías canónicas estándar para cada bodega activa
DO $$
DECLARE
    r_bodega RECORD;
BEGIN
    FOR r_bodega IN SELECT id_bodega, nombre_comercial FROM bodegas WHERE estado = TRUE LOOP
        -- Bebidas y Gaseosas
        INSERT INTO categorias (id_bodega, nombre, descripcion, estado, fecha_creacion, fecha_actualizacion)
        SELECT r_bodega.id_bodega, 'Bebidas y Gaseosas', 'Gaseosas, aguas minerales, jugos, energizantes e hidratantes', TRUE, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM categorias WHERE id_bodega = r_bodega.id_bodega AND LOWER(nombre) IN ('bebidas y gaseosas', 'gaseosas y bebidas', 'bebidas'));

        -- Licores y Cervezas
        INSERT INTO categorias (id_bodega, nombre, descripcion, estado, fecha_creacion, fecha_actualizacion)
        SELECT r_bodega.id_bodega, 'Licores y Cervezas', 'Cervezas nacionales e importadas, vinos, piscos y licores', TRUE, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM categorias WHERE id_bodega = r_bodega.id_bodega AND LOWER(nombre) IN ('licores y cervezas', 'bebidas alcohólicas', 'cervezas y licores'));

        -- Lácteos y Huevos
        INSERT INTO categorias (id_bodega, nombre, descripcion, estado, fecha_creacion, fecha_actualizacion)
        SELECT r_bodega.id_bodega, 'Lácteos y Huevos', 'Leche evaporada, fresca, yogures, mantequillas, quesos y huevos', TRUE, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM categorias WHERE id_bodega = r_bodega.id_bodega AND LOWER(nombre) IN ('lácteos y huevos', 'lácteos y derivados', 'lacteos'));

        -- Abarrotes y Despensa
        INSERT INTO categorias (id_bodega, nombre, descripcion, estado, fecha_creacion, fecha_actualizacion)
        SELECT r_bodega.id_bodega, 'Abarrotes y Despensa', 'Arroz, azúcar, fideos, aceites, conservas, salsas y condimentos', TRUE, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM categorias WHERE id_bodega = r_bodega.id_bodega AND LOWER(nombre) IN ('abarrotes y despensa', 'abarrotes y fideos', 'abarrotes'));

        -- Snacks y Golosinas
        INSERT INTO categorias (id_bodega, nombre, descripcion, estado, fecha_creacion, fecha_actualizacion)
        SELECT r_bodega.id_bodega, 'Snacks y Golosinas', 'Papas fritas, galletas dulces y saladas, chocolates y caramelos', TRUE, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM categorias WHERE id_bodega = r_bodega.id_bodega AND LOWER(nombre) IN ('snacks y golosinas', 'snacks y piqueos', 'golosinas y chocolates'));

        -- Embutidos y Fiambrería
        INSERT INTO categorias (id_bodega, nombre, descripcion, estado, fecha_creacion, fecha_actualizacion)
        SELECT r_bodega.id_bodega, 'Embutidos y Fiambrería', 'Jamones, salchichas, tocinos, chorizos y quesos empaquetados', TRUE, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM categorias WHERE id_bodega = r_bodega.id_bodega AND LOWER(nombre) IN ('embutidos y fiambrería', 'embutidos y fiambres', 'embutidos'));

        -- Panadería y Desayuno
        INSERT INTO categorias (id_bodega, nombre, descripcion, estado, fecha_creacion, fecha_actualizacion)
        SELECT r_bodega.id_bodega, 'Panadería y Desayuno', 'Pan de molde, mermeladas, avenas, café, té e infusiones', TRUE, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM categorias WHERE id_bodega = r_bodega.id_bodega AND LOWER(nombre) IN ('panadería y desayuno', 'panadería y desayunos', 'desayuno'));

        -- Limpieza del Hogar
        INSERT INTO categorias (id_bodega, nombre, descripcion, estado, fecha_creacion, fecha_actualizacion)
        SELECT r_bodega.id_bodega, 'Limpieza del Hogar', 'Detergentes, lejías, lavavajillas, desinfectantes y esponjas', TRUE, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM categorias WHERE id_bodega = r_bodega.id_bodega AND LOWER(nombre) IN ('limpieza del hogar', 'limpieza y cuidado del hogar', 'limpieza'));

        -- Cuidado Personal
        INSERT INTO categorias (id_bodega, nombre, descripcion, estado, fecha_creacion, fecha_actualizacion)
        SELECT r_bodega.id_bodega, 'Cuidado Personal', 'Jabones de tocador, champús, cremas dentales y papel higiénico', TRUE, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM categorias WHERE id_bodega = r_bodega.id_bodega AND LOWER(nombre) IN ('cuidado personal', 'cuidado personal y dental'));

        -- Helados y Congelados
        INSERT INTO categorias (id_bodega, nombre, descripcion, estado, fecha_creacion, fecha_actualizacion)
        SELECT r_bodega.id_bodega, 'Helados y Congelados', 'Helados Donofrio, paletas, conos, bombones y postres fríos', TRUE, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM categorias WHERE id_bodega = r_bodega.id_bodega AND LOWER(nombre) IN ('helados y congelados', 'helados y postres', 'helados'));

        -- Cigarrillos y Tabaco
        INSERT INTO categorias (id_bodega, nombre, descripcion, estado, fecha_creacion, fecha_actualizacion)
        SELECT r_bodega.id_bodega, 'Cigarrillos y Tabaco', 'Cajetillas Lucky Strike, Pall Mall, Hamilton y encendedores', TRUE, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM categorias WHERE id_bodega = r_bodega.id_bodega AND LOWER(nombre) IN ('cigarrillos y tabaco', 'cigarrillos y tabacos', 'tabacos'));
    END LOOP;
END $$;

-- 2. Tabla temporal del catálogo maestro oficial
CREATE TEMP TABLE temp_catalogo_maestro (
    codigo_barras VARCHAR(100),
    nombre VARCHAR(150),
    marca VARCHAR(100),
    categoria_nombre VARCHAR(100),
    precio_venta NUMERIC(12,2),
    precio_costo NUMERIC(12,2),
    imagen_url VARCHAR(500),
    codigos_alternos TEXT[]
);

INSERT INTO temp_catalogo_maestro (codigo_barras, nombre, marca, categoria_nombre, precio_venta, precio_costo, imagen_url, codigos_alternos) VALUES
('7750107002030', 'Salchicha Huachana Laive 250g', 'Laive', 'Embutidos y Fiambrería', 6.80, 5.20, 'packshots/salchicha_huachana.png', ARRAY['7750107002030']::TEXT[]),
('7750107002047', 'Tocino Ahumado en Tiras Braedt 170g', 'Braedt', 'Embutidos y Fiambrería', 6.80, 5.20, 'packshots/tocino_braedt.png', ARRAY['7750107002047']::TEXT[]),
('7750107002054', 'Chorizo Parrillero San Fernando pack x4', 'San Fernando', 'Embutidos y Fiambrería', 4.50, 3.50, 'packshots/chorizo_parrillero.png', ARRAY['7750107002054']::TEXT[]),
('7750107002061', 'Queso Edam Laminado Laive 200g', 'Laive', 'Embutidos y Fiambrería', 4.50, 3.50, 'packshots/queso_edam.png', ARRAY['7750107002061']::TEXT[]),
('7750107002078', 'Queso Fresco Bonlé Gloria 400g', 'Gloria', 'Embutidos y Fiambrería', 4.50, 3.50, 'packshots/queso_fresco_bonle.png', ARRAY['7750107002078']::TEXT[]),
('7750107002085', 'Jamón del País Braedt 150g', 'Braedt', 'Embutidos y Fiambrería', 6.80, 5.20, 'packshots/jamon_del_pais.png', ARRAY['7750107002085']::TEXT[]),
('7750108003013', 'Leche Gloria Azul Evaporada 400g', 'Gloria', 'Lácteos y Huevos', 4.50, 3.80, 'packshots/leche_gloria_azul.png', ARRAY['7750108003013', '7750243000012']::TEXT[]),
('7750108003020', 'Leche Gloria Roja Entera 400g', 'Gloria', 'Lácteos y Huevos', 4.50, 3.80, 'packshots/leche_gloria_roja.png', ARRAY['7750108003020']::TEXT[]),
('7750108003037', 'Leche Gloria Light 400g', 'Gloria', 'Lácteos y Huevos', 4.50, 3.80, 'packshots/leche_gloria_light.png', ARRAY['7750108003037']::TEXT[]),
('7750108003044', 'Leche Gloria Sin Lactosa 400g', 'Gloria', 'Lácteos y Huevos', 4.50, 3.80, 'packshots/leche_gloria_sin_lactosa.png', ARRAY['7750108003044']::TEXT[]),
('7750108003051', 'Leche Chocolatada Gloria 1 Litro', 'Gloria', 'Lácteos y Huevos', 4.50, 3.80, 'packshots/leche_chocolatada_gloria.png', ARRAY['7750108003051']::TEXT[]),
('775117011953', 'Agua San Mateo 600ml Sin Gas', 'San Mateo', 'Bebidas y Gaseosas', 2.00, 1.40, 'packshots/agua_san_mateo.png', ARRAY['775117011953', '775435704798', '775386598917', '775544203715', '775620527268']::TEXT[]),
('7750109004140', 'Crema de Ají Tarí Alacena Doypack 400g', 'Alacena', 'Abarrotes y Despensa', 5.50, 4.20, 'packshots/mayonesa_alacena.png', ARRAY['7750109004140', '7750109004133']::TEXT[]),
('7750113008025', 'Crema Dental Colgate Total 12 Limpieza 75ml', 'Colgate', 'Cuidado Personal', 5.50, 4.20, 'packshots/colgate_total12.png', ARRAY['7750113008025']::TEXT[]),
('7750113008032', 'Crema Dental Colgate Triple Acción 75ml', 'Colgate', 'Cuidado Personal', 5.50, 4.20, 'packshots/colgate_triple_accion.png', ARRAY['7750113008032']::TEXT[]),
('7750107002023', 'Jamonada de Pollo San Fernando 450g', 'San Fernando', 'Embutidos y Fiambrería', 6.80, 5.20, 'packshots/jamonada_san_fernando.png', ARRAY['7750107002023']::TEXT[]),
('7750113008049', 'Cepillo Dental Colgate Zig Zag Medio', 'Colgate', 'Cuidado Personal', 5.50, 4.20, 'packshots/cepillo_colgate.png', ARRAY['7750113008049']::TEXT[]),
('7750116011018', 'Pan de Molde Blanco Bimbo Chico 400g', 'Bimbo', 'Panadería y Desayuno', 6.50, 5.10, 'packshots/pan_bimbo_blanco.png', ARRAY['7750116011018']::TEXT[]),
('7750116011025', 'Pan de Molde Integral Bimbo 400g', 'Bimbo', 'Panadería y Desayuno', 6.50, 5.10, 'packshots/pan_bimbo_integral.png', ARRAY['7750116011025']::TEXT[]),
('7750116011049', 'Café Soluble Nescafé Tradición Frasco 50g', 'Nescafé', 'Panadería y Desayuno', 9.50, 7.50, 'packshots/cafe_nescafe.png', ARRAY['7750116011049']::TEXT[]),
('7750115010073', 'Galleta Tentación Chocolate 70g', 'Victoria', 'Snacks y Golosinas', 1.50, 1.10, 'packshots/galleta_tentacion.png', ARRAY['7750115010073']::TEXT[]),
('7750106001010', 'Inca Kola 500ml', 'Inca Kola', 'Bebidas y Gaseosas', 3.50, 2.70, 'packshots/inka_kola.png', ARRAY['7750106001010', '7750106001027', '7750106001034', '7750106000018']::TEXT[]),
('7751234567890', 'Coca Cola 3 Litros', 'Coca Cola', 'Bebidas y Gaseosas', 13.50, 11.20, 'packshots/coca_cola.png', ARRAY['7751234567890', '7750106002017', '7750106002024', '7750106000025']::TEXT[]),
('7750115010059', 'Galleta Casino Fresa 68g', 'Victoria', 'Snacks y Golosinas', 1.50, 1.10, 'packshots/galleta_casino.png', ARRAY['7750115010059']::TEXT[]),
('7750115010080', 'Galleta Oreo Original Tubo 108g', 'Oreo', 'Snacks y Golosinas', 1.50, 1.10, 'packshots/galleta_oreo.png', ARRAY['7750115010080']::TEXT[]),
('7750115010066', 'Galleta Margarita Clásica 80g', 'Sayón', 'Snacks y Golosinas', 1.50, 1.10, 'packshots/galleta_margarita.png', ARRAY['7750115010066']::TEXT[]),
('7750115010097', 'Pastillas Halls Extra Fuerte Menta', 'Halls', 'Snacks y Golosinas', 4.50, 3.50, 'packshots/halls_menta.png', ARRAY['7750115010097']::TEXT[]),
('7750115010103', 'Caramelos Chicho Surtido Paquete 100g', 'Chicho', 'Snacks y Golosinas', 4.50, 3.50, 'packshots/caramelos_chicho.png', ARRAY['7750115010103']::TEXT[]),
('7750116011032', 'Mermelada de Fresa Gloria Vaso 310g', 'Gloria', 'Panadería y Desayuno', 5.80, 4.50, 'packshots/mermelada_gloria.png', ARRAY['7750116011032']::TEXT[]),
('7750116011056', 'Avena Precocida 3 Ositos Bolsa 250g', '3 Ositos', 'Panadería y Desayuno', 4.50, 3.50, 'packshots/avena_tres_ositos.png', ARRAY['7750116011056']::TEXT[]),
('7750116011063', 'Té Herbi Clásico Caja x25 bolsitas', 'Herbi', 'Panadería y Desayuno', 4.50, 3.50, 'packshots/te_herbi.png', ARRAY['7750116011063']::TEXT[]),
('7750116011070', 'Manzanilla Herbi Caja x25 bolsitas', 'Herbi', 'Panadería y Desayuno', 4.50, 3.50, 'packshots/manzanilla_herbi.png', ARRAY['7750116011070']::TEXT[]),
('7750109004089', 'Azúcar Rubia Paramonga 1kg', 'Paramonga', 'Abarrotes y Despensa', 4.50, 3.50, 'packshots/azucar_paramonga.png', ARRAY['7750109004089']::TEXT[]),
('7750075001081', 'Piqueo Snax Familiar 200g', 'Frito-Lay', 'Snacks y Golosinas', 2.50, 1.90, 'packshots/piqueo_snax.png', ARRAY['7750075001081']::TEXT[]),
('7750109004072', 'Aceite Vegetal Cocinero 900ml', 'Cocinero', 'Abarrotes y Despensa', 9.50, 7.80, 'packshots/aceite_cocinero.png', ARRAY['7750109004072']::TEXT[]),
('7750109004119', 'Filete de Atún Fanny en Aceite 170g', 'Fanny', 'Abarrotes y Despensa', 8.50, 6.90, 'packshots/atun_fanny.png', ARRAY['7750109004119']::TEXT[]),
('7750110005031', 'Helado Sin Parar Lúcuma Chispas', 'D''Onofrio', 'Helados y Congelados', 4.00, 3.00, 'packshots/helado_sin_parar.png', ARRAY['7750110005031']::TEXT[]),
('7750110005079', 'Helado Bombones D''Onofrio Caja x8', 'D''Onofrio', 'Helados y Congelados', 4.00, 3.00, 'packshots/helado_bombones.png', ARRAY['7750110005079']::TEXT[]),
('7750111006052', 'Ron Cartavio Black 750ml', 'Cartavio', 'Licores y Cervezas', 4.50, 3.50, 'packshots/ron_cartavio.png', ARRAY['7750111006052']::TEXT[]),
('7750111006076', 'Vino Tinto Tabernero Borgoña 750ml', 'Tabernero', 'Licores y Cervezas', 4.50, 3.50, 'packshots/vino_tabernero.png', ARRAY['7750111006076']::TEXT[]),
('7750112007028', 'Hamilton Rojo Clásico Cajetilla x20', 'Hamilton', 'Cigarrillos y Tabaco', 4.50, 3.50, 'packshots/helado_jet.png', ARRAY['7750112007028', '7750110005062', '7750112007011', '7750112007035', '7750112007042']::TEXT[]),
('7750112007059', 'Encendedor Tokai Clásico Descartable', 'Tokai', 'Cigarrillos y Tabaco', 4.50, 3.50, 'packshots/encendedor_tokai.png', ARRAY['7750112007059']::TEXT[]),
('7750113008056', 'Jabón de Tocador Camay Clásico 125g', 'Camay', 'Cuidado Personal', 3.20, 2.40, 'packshots/jabon_camay.png', ARRAY['7750113008056']::TEXT[]),
('7750113008087', 'Shampoo Pantene Restauración 375ml', 'Pantene', 'Cuidado Personal', 18.50, 15.00, 'packshots/shampoo_pantene.png', ARRAY['7750113008087', '7908132297479']::TEXT[]),
('7750114009046', 'Crema de Ají Tarí Alacena Doypack 400g', 'Alacena', 'Abarrotes y Despensa', 5.50, 4.20, '/crema_tari.png', ARRAY['7750114009046']::TEXT[]),
('7750114009053', 'Fósforos La Llama paquete x10 cajitas', 'La Llama', 'Cigarrillos y Tabaco', 4.50, 3.50, '/fosforos_la_llama.png', ARRAY['7750114009053']::TEXT[]),
('7750114009084', 'Suavizante Suavitel Fresca Primavera 850ml', 'Suavitel', 'Limpieza del Hogar', 4.50, 3.50, 'packshots/suavizante_suavitel.png', ARRAY['7750114009084']::TEXT[]),
('7755236000632', 'Gel Antibacterial', 'Genérico', 'Cuidado Personal', 4.50, 3.50, 'packshots/gel_antibacterial.png', ARRAY['7755236000632']::TEXT[]),
('7750109004010', 'Fideos Don Vittorio Spaghetti 450g', 'Don Vittorio', 'Abarrotes y Despensa', 3.20, 2.50, 'packshots/fideos_spaghetti_don_vittorio.png', ARRAY['7750109004010']::TEXT[]),
('7750109004034', 'Fideos Don Vittorio Codito 450g', 'Don Vittorio', 'Abarrotes y Despensa', 3.20, 2.50, 'packshots/fideos_codito_don_vittorio.png', ARRAY['7750109004034']::TEXT[]),
('7750075001012', 'Papas Lays Ondas Cebolla y Queso 150g', 'Lays', 'Snacks y Golosinas', 2.50, 1.90, 'packshots/lays_onduladas.png', ARRAY['7750075001012']::TEXT[]),
('7750109004041', 'Arroz Extra Costeño Bolsa 1kg', 'Costeño', 'Abarrotes y Despensa', 4.90, 4.00, 'packshots/arroz_costeno.png', ARRAY['7750109004041', '7750350000010']::TEXT[]),
('7750108003068', 'Yogur Gloria Fresa 1 Litro', 'Gloria', 'Lácteos y Huevos', 3.50, 2.80, 'packshots/yogur_gloria_fresa.png', ARRAY['7750108003068']::TEXT[]),
('7750108003075', 'Yogur Gloria Vainilla Francesa 1 Litro', 'Gloria', 'Lácteos y Huevos', 3.50, 2.80, 'packshots/yogur_gloria_vainilla.png', ARRAY['7750108003075']::TEXT[]),
('7750108003082', 'Mantequilla con Sal Laive Barra 200g', 'Laive', 'Lácteos y Huevos', 4.50, 3.50, 'packshots/mantequilla_laive.png', ARRAY['7750108003082']::TEXT[]),
('7750108003099', 'Margarina Manty Pote 225g', 'Alicorp', 'Lácteos y Huevos', 4.50, 3.50, 'packshots/margarina_manty.png', ARRAY['7750108003099']::TEXT[]),
('7750108003105', 'Leche Condensada Nestlé 393g', 'Nestlé', 'Lácteos y Huevos', 4.50, 3.70, 'packshots/leche_condensada_nestle.png', ARRAY['7750108003105']::TEXT[]),
('7750109004027', 'Fideos Lavaggi Canuto Corto 450g', 'Lavaggi', 'Abarrotes y Despensa', 3.20, 2.50, 'packshots/fideos_canuto_lavaggi.png', ARRAY['7750109004027']::TEXT[]),
('7750109004058', 'Arroz Superior Faraón Bolsa 1kg', 'Faraón', 'Abarrotes y Despensa', 4.90, 4.00, 'packshots/arroz_faraon.png', ARRAY['7750109004058']::TEXT[]),
('7750110005055', 'Helado Peziduri Tricolor 1L', 'D''Onofrio', 'Helados y Congelados', 4.00, 3.00, 'packshots/helado_peziduri_tricolor.png', ARRAY['7750110005055']::TEXT[]),
('7750111006045', 'Cerveza Stella Artois 330ml Botella', 'Stella Artois', 'Licores y Cervezas', 4.50, 3.50, 'packshots/cerveza_stella.png', ARRAY['7750111006045']::TEXT[]),
('7750109004065', 'Aceite Vegetal Primor Premium 900ml', 'Primor', 'Abarrotes y Despensa', 9.50, 7.80, 'packshots/aceite_primor.png', ARRAY['7750109004065', '7750109004102', '7750350000027']::TEXT[]),
('7750111006021', 'Cerveza Pilsen Callao 650ml Retornable', 'Backus', 'Licores y Cervezas', 28.00, 23.50, 'packshots/cerveza_pilsen.png', ARRAY['7750111006021', '7750106007012']::TEXT[]),
('7750111006014', 'Cerveza Cristal 650ml Botella Retornable', 'Backus', 'Licores y Cervezas', 28.00, 23.50, 'packshots/cerveza_cristal.png', ARRAY['7750111006014']::TEXT[]),
('7750110005017', 'Helado Sublime D''Onofrio Paleta', 'D''Onofrio', 'Helados y Congelados', 3.00, 2.30, 'packshots/helado_sublime.png', ARRAY['7750110005017']::TEXT[]),
('7750075001029', 'Doritos Mega Queso 150g', 'Frito-Lay', 'Snacks y Golosinas', 2.50, 1.90, 'packshots/doritos_queso.png', ARRAY['7750075001029']::TEXT[]),
('7750075001036', 'Chizitos Fiesta Queso 160g', 'Frito-Lay', 'Snacks y Golosinas', 4.50, 3.50, 'packshots/chizitos_queso.png', ARRAY['7750075001036']::TEXT[]),
('7750113008018', 'Crema Dental Kolynos Triple Limpieza 120g', 'Kolynos', 'Cuidado Personal', 5.50, 4.20, 'packshots/kolynos.png', ARRAY['7750113008018']::TEXT[]),
('7750075001043', 'Cuates Picantes 150g', 'Karinto', 'Snacks y Golosinas', 2.50, 1.90, 'packshots/cuates_picantes.png', ARRAY['7750075001043']::TEXT[]),
('7750075001050', 'Chifle Piurano Salado 100g', 'Karinto', 'Snacks y Golosinas', 4.50, 3.50, 'packshots/chifle_piurano.png', ARRAY['7750075001050']::TEXT[]),
('7750075001067', 'Maní Salado Karinto 100g', 'Karinto', 'Snacks y Golosinas', 4.50, 3.50, 'packshots/mani_karinto.png', ARRAY['7750075001067']::TEXT[]),
('7750075001074', 'Tortees Picantes 140g', 'Frito-Lay', 'Snacks y Golosinas', 4.50, 3.50, 'packshots/tortees_picantes.png', ARRAY['7750075001074']::TEXT[]),
('7750075001098', 'Cheese Tris 150g', 'Frito-Lay', 'Snacks y Golosinas', 4.50, 3.50, 'packshots/cheese_tris.png', ARRAY['7750075001098']::TEXT[]),
('7750107002016', 'Hot Dog de Pollo San Fernando 500g', 'San Fernando', 'Embutidos y Fiambrería', 6.80, 5.20, 'packshots/hot_dog_san_fernando.png', ARRAY['7750107002016']::TEXT[]),
('7750109004096', 'Sal Yodada Marina Emsal 1kg', 'Emsal', 'Abarrotes y Despensa', 4.50, 3.50, 'packshots/sal_emsal.png', ARRAY['7750109004096']::TEXT[]),
('7750109004126', 'Salsa de Tomate Tuco Sibarita 260g', 'Sibarita', 'Abarrotes y Despensa', 4.50, 3.50, 'packshots/tuco_sibarita.png', ARRAY['7750109004126']::TEXT[]),
('7750110005024', 'Helado Frío Rico Vainilla y Lúcuma', 'D''Onofrio', 'Helados y Congelados', 4.00, 3.00, 'packshots/helado_frio_rico.png', ARRAY['7750110005024']::TEXT[]),
('7750110005048', 'Helado Peziduri Vainilla Chispas 1L', 'D''Onofrio', 'Helados y Congelados', 4.00, 3.00, 'packshots/helado_peziduri_vainilla.png', ARRAY['7750110005048']::TEXT[]),
('7750110005086', 'Helado Morochas D''Onofrio', 'D''Onofrio', 'Helados y Congelados', 1.50, 1.10, 'packshots/helado_morochas.png', ARRAY['7750110005086']::TEXT[]),
('7750111006038', 'Cerveza Corona Extra 355ml Botella', 'Corona', 'Licores y Cervezas', 5.00, 3.90, 'packshots/cerveza_corona.png', ARRAY['7750111006038']::TEXT[]),
('7750111006069', 'Pisco Queirolo Quebranta 750ml', 'Santiago Queirolo', 'Licores y Cervezas', 4.50, 3.50, 'packshots/pisco_queirolo.png', ARRAY['7750111006069']::TEXT[]),
('7750111006083', 'Whisky Johnnie Walker Red Label 750ml', 'Johnnie Walker', 'Licores y Cervezas', 4.50, 3.50, 'packshots/whisky_johnnie_walker.png', ARRAY['7750111006083']::TEXT[]),
('7750113008063', 'Jabón de Tocador Dove Original 90g', 'Dove', 'Cuidado Personal', 3.20, 2.40, 'packshots/jabon_dove.png', ARRAY['7750113008063']::TEXT[]),
('7750113008070', 'Shampoo Head & Shoulders Limpieza 375ml', 'Head & Shoulders', 'Cuidado Personal', 18.50, 15.00, 'packshots/shampoo_head_shoulders.png', ARRAY['7750113008070']::TEXT[]),
('7750113008094', 'Desodorante Rexona Men Aerosol 150ml', 'Rexona', 'Cuidado Personal', 4.50, 3.50, 'packshots/rexona_men.png', ARRAY['7750113008094']::TEXT[]),
('7750113008100', 'Desodorante Rexona Women Aerosol 150ml', 'Rexona', 'Cuidado Personal', 4.50, 3.50, 'packshots/rexona_women.png', ARRAY['7750113008100']::TEXT[]),
('7750106009999', 'Papas Lays Clásicas 160g', 'Lays', 'Snacks y Golosinas', 2.50, 1.90, 'packshots/lays_clasicas.png', ARRAY['7750106009999']::TEXT[]),
('7750115010011', 'Chocolate Sublime Clásico 30g', 'Nestlé', 'Snacks y Golosinas', 3.00, 2.30, 'packshots/chocolate_sublime.png', ARRAY['7750115010011']::TEXT[]),
('7750115010028', 'Chocolate Triángulo D''Onofrio 30g', 'D''Onofrio', 'Snacks y Golosinas', 4.00, 3.00, 'packshots/chocolate_triangulo.png', ARRAY['7750115010028']::TEXT[]),
('7750115010035', 'Galleta Cua Cua Chocolate 18g', 'Field', 'Snacks y Golosinas', 1.50, 1.10, 'packshots/galleta_cua_cua.png', ARRAY['7750115010035']::TEXT[]),
('7750115010042', 'Galleta Doña Pepa 23g', 'Field', 'Snacks y Golosinas', 1.50, 1.10, 'packshots/galleta_dona_pepa.png', ARRAY['7750115010042']::TEXT[]),
('7750114009015', 'Detergente Bolívar Blanco Activo 850g', 'Bolívar', 'Limpieza del Hogar', 9.90, 8.00, 'packshots/detergente_bolivar.png', ARRAY['7750114009015']::TEXT[]),
('7750106006015', 'Cerveza Cusqueña Trigo 310ml', 'Cusqueña', 'Licores y Cervezas', 6.50, 5.20, 'packshots/cerveza_cusquena.png', ARRAY['7750106006015']::TEXT[]),
('7750106008019', 'Fanta Naranja 500ml', 'Fanta', 'Bebidas y Gaseosas', 4.50, 3.50, 'packshots/fanta.png', ARRAY['7750106008019']::TEXT[]),
('7751507293994', 'Guaraná 3 Lt', 'Backus', 'Bebidas y Gaseosas', 4.50, 3.50, 'packshots/guarana.png', ARRAY['7751507293994']::TEXT[]),
('7750106003014', 'Agua San Luis 625ml Sin Gas', 'San Luis', 'Bebidas y Gaseosas', 2.00, 1.40, 'packshots/agua_san_luis.png', ARRAY['7750106003014']::TEXT[]),
('7750670010238', 'Sporade 500ml Tropical', 'Sporade', 'Bebidas y Gaseosas', 4.50, 3.50, 'packshots/sporade.png', ARRAY['7750670010238']::TEXT[]),
('7750106005018', 'Cifrut 500ml Granadilla', 'Cifrut', 'Bebidas y Gaseosas', 4.50, 3.50, 'packshots/cifrut.png', ARRAY['7750106005018']::TEXT[]),
('9002490100070', 'Red Bull Energy Drink 250ml', 'Red Bull', 'Bebidas y Gaseosas', 4.50, 3.50, 'packshots/red_bull.png', ARRAY['9002490100070']::TEXT[]),
('7750113008117', 'Papel Higiénico Suave Rindemax x4 rollos', 'Suave', 'Cuidado Personal', 6.50, 5.00, 'packshots/papel_higienico_suave.png', ARRAY['7750113008117']::TEXT[]),
('7750113008124', 'Toallas Higiénicas Nosotras x10', 'Nosotras', 'Cuidado Personal', 4.50, 3.50, 'packshots/toallas_nosotras.png', ARRAY['7750113008124']::TEXT[]),
('7750114009022', 'Detergente Ace Limpieza Completa 750g', 'Ace', 'Limpieza del Hogar', 5.50, 4.20, 'packshots/detergente_ace.png', ARRAY['7750114009022']::TEXT[]),
('7750114009039', 'Detergente Opal Ultra 750g', 'Opal', 'Limpieza del Hogar', 5.50, 4.20, 'packshots/detergente_opal.png', ARRAY['7750114009039']::TEXT[]),
('7750114009060', 'Lejía Clorox Tradicional 1 Litro', 'Clorox', 'Limpieza del Hogar', 4.50, 3.50, 'packshots/lejia_clorox.png', ARRAY['7750114009060']::TEXT[]),
('7750114009077', 'Limpiador Multiusos Poett Lavanda 900ml', 'Poett', 'Limpieza del Hogar', 4.50, 3.50, 'packshots/limpiador_poett.png', ARRAY['7750114009077']::TEXT[]),
('7750114009091', 'Esponja Verde Scotch Brite Clásica', 'Scotch Brite', 'Limpieza del Hogar', 4.50, 3.50, 'packshots/esponja_scotch.png', ARRAY['7750114009091']::TEXT[]),
('7750114009107', 'Bolsas de Basura Negras Grande x10', 'Sapolio', 'Limpieza del Hogar', 4.50, 3.50, 'packshots/bolsas_basura.png', ARRAY['7750114009107']::TEXT[]),
('6977326450007', 'Hisopo', 'Santoler', 'Cuidado Personal', 4.50, 3.50, 'packshots/hisopos_santoler.png', ARRAY['6977326450007']::TEXT[]);

-- 3. Procesar e insertar / sincronizar en la entidad productos de cada bodega activa
DO $$
DECLARE
    r_bodega RECORD;
    r_prod RECORD;
    v_id_cat BIGINT;
    v_id_prod BIGINT;
    v_codigo_generado VARCHAR(50);
BEGIN
    FOR r_bodega IN SELECT id_bodega FROM bodegas WHERE estado = TRUE LOOP
        FOR r_prod IN SELECT * FROM temp_catalogo_maestro LOOP
            -- Resolver categoría para la bodega
            SELECT id_categoria INTO v_id_cat
            FROM categorias
            WHERE id_bodega = r_bodega.id_bodega
              AND (
                  LOWER(nombre) = LOWER(r_prod.categoria_nombre)
                  OR LOWER(nombre) LIKE LOWER('%' || split_part(r_prod.categoria_nombre, ' ', 1) || '%')
              )
            ORDER BY id_categoria ASC
            LIMIT 1;

            IF v_id_cat IS NULL THEN
                SELECT id_categoria INTO v_id_cat FROM categorias WHERE id_bodega = r_bodega.id_bodega AND estado = TRUE LIMIT 1;
            END IF;

            -- Verificar si el producto ya existe en la bodega
            SELECT id_producto INTO v_id_prod
            FROM productos
            WHERE id_bodega = r_bodega.id_bodega
              AND (
                  codigo_barras = r_prod.codigo_barras
                  OR (r_prod.codigos_alternos IS NOT NULL AND codigo_barras = ANY(r_prod.codigos_alternos))
                  OR LOWER(nombre) = LOWER(r_prod.nombre)
              )
            ORDER BY id_producto ASC
            LIMIT 1;

            IF v_id_prod IS NOT NULL THEN
                -- Enriquecer producto existente con su código oficial y fotografía packshot
                UPDATE productos
                SET codigo_barras = CASE 
                        WHEN EXISTS (
                            SELECT 1 FROM productos p2 
                            WHERE p2.id_bodega = r_bodega.id_bodega 
                              AND p2.id_producto != v_id_prod 
                              AND p2.codigo_barras = r_prod.codigo_barras 
                              AND p2.estado = TRUE
                        ) THEN codigo_barras
                        ELSE r_prod.codigo_barras
                    END,
                    imagen_url = COALESCE(NULLIF(imagen_url, ''), r_prod.imagen_url),
                    marca = COALESCE(NULLIF(marca, ''), r_prod.marca),
                    id_categoria = COALESCE(id_categoria, v_id_cat),
                    fecha_actualizacion = NOW()
                WHERE id_producto = v_id_prod;
            ELSE
                -- Asegurar que no exista ya otro producto con el mismo código de barras en la bodega
                IF NOT EXISTS (
                    SELECT 1 FROM productos 
                    WHERE id_bodega = r_bodega.id_bodega 
                      AND codigo_barras = r_prod.codigo_barras 
                      AND estado = TRUE
                ) THEN
                    -- Generar código comercial interno único
                    v_codigo_generado := 'PROD-' || r_prod.codigo_barras;
                    IF EXISTS (SELECT 1 FROM productos WHERE id_bodega = r_bodega.id_bodega AND codigo = v_codigo_generado) THEN
                        v_codigo_generado := v_codigo_generado || '-' || substr(md5(random()::text), 1, 4);
                    END IF;

                    INSERT INTO productos (
                        id_bodega, id_categoria, codigo, codigo_barras, nombre, marca,
                        precio_venta, stock_actual, stock_minimo, controla_vencimiento,
                        precio_costo, imagen_url, estado, fecha_creacion, fecha_actualizacion
                    ) VALUES (
                        r_bodega.id_bodega, v_id_cat, v_codigo_generado, r_prod.codigo_barras, r_prod.nombre, r_prod.marca,
                        r_prod.precio_venta, 24.000, 5.000, FALSE,
                        r_prod.precio_costo, r_prod.imagen_url, TRUE, NOW(), NOW()
                    );
                END IF;
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- 4. Limpieza de tabla temporal
DROP TABLE IF EXISTS temp_catalogo_maestro;
