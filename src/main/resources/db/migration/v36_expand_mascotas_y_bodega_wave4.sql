-- ==============================================================================
-- Migración v36: Expansión Comercial Ola 4 — Nueva categoría "Mascotas y Alimento"
-- (+14 productos de comida para perros: Ricocan, Mimaskot, Dogui, Dog Chow, Pedigree;
-- +3 de comida para gatos: Ricocat) + 15 productos peruanos de alta rotación
-- (Menestras Costeño, Soda Field, Ritz, Morochas, Pringles, Blanca Flor, Venturo,
-- Mostaza AlaCena, Manjar Nestlé, Yogur Laive, Mini Panetón, Glade) con EAN-13 reales
-- y fotografías oficiales de estudio. 100% idempotente.
-- ==============================================================================

DO $$
DECLARE
    v_bodega RECORD;
    v_bodega_id BIGINT;
    v_cat_id BIGINT;
    v_item RECORD;
BEGIN
    -- 1. Asegurar la nueva categoría canónica "Mascotas y Alimento" en todas las bodegas
    FOR v_bodega IN SELECT id_bodega FROM bodegas LOOP
        IF NOT EXISTS (
            SELECT 1 FROM categorias
            WHERE id_bodega = v_bodega.id_bodega
              AND LOWER(TRIM(nombre)) = 'mascotas y alimento'
        ) THEN
            INSERT INTO categorias (nombre, descripcion, estado, id_bodega)
            VALUES (
                'Mascotas y Alimento',
                'Comida para perros y gatos en bolsa, sobres húmedos y paté en lata',
                TRUE,
                v_bodega.id_bodega
            );
        END IF;
    END LOOP;

    -- 2. Reparar imagen de Mostaza AlaCena existente (antes apuntaba a concordia_pina.png)
    UPDATE productos
    SET imagen_url = 'packshots/mostaza_alacena.png'
    WHERE nombre ILIKE '%Mostaza AlaCena%'
      AND (imagen_url IS NULL OR imagen_url = '' OR imagen_url = 'packshots/concordia_pina.png');

    -- 3. Registrar los 32 productos reales en el Preset Global del SuperAdmin
    INSERT INTO catalogo_starter_pack_global (
        codigo_barras, nombre, marca, categoria, precio_venta, precio_costo, imagen_url, activo
    ) VALUES
        -- Comida para Perros
        ('7753176005159', 'Comida para Perro Ricocan Adulto Raza Pequeña Cordero 1kg', 'Ricocan', 'Mascotas y Alimento', 11.50, 9.20, 'packshots/ricocan_cordero_1kg.png', TRUE),
        ('7753176001434', 'Comida para Perro Ricocan Adulto Multisabores 1kg', 'Ricocan', 'Mascotas y Alimento', 11.50, 9.20, 'packshots/ricocan_adulto_multi_1kg.png', TRUE),
        ('7753176004107', 'Comida para Perro Ricocan Cachorros Carne y Leche 1kg', 'Ricocan', 'Mascotas y Alimento', 11.90, 9.50, 'packshots/ricocan_cachorro_1kg.png', TRUE),
        ('7753176005104', 'Paté para Perro Ricocan Adulto Cordero Lata 330g', 'Ricocan', 'Mascotas y Alimento', 5.50, 4.30, 'packshots/ricocan_pate_cordero_330g.png', TRUE),
        ('7753176000567', 'Paté para Perro Ricocan Cachorro Lata 330g', 'Ricocan', 'Mascotas y Alimento', 5.50, 4.30, 'packshots/ricocan_pate_cachorro_330g.png', TRUE),
        ('7753176003049', 'Sobre Ricocan Trocitos en Salsa Cordero 100g', 'Ricocan', 'Mascotas y Alimento', 3.80, 2.95, 'packshots/ricocan_sobre_cordero_100g.png', TRUE),
        ('7750885026376', 'Comida para Perro Mimaskot Adulto Carne 1kg', 'Mimaskot', 'Mascotas y Alimento', 12.50, 10.00, 'packshots/mimaskot_adulto_carne_1kg.png', TRUE),
        ('7750885026345', 'Comida para Perro Mimaskot Adulto Carne Bolsa 3kg', 'Mimaskot', 'Mascotas y Alimento', 29.90, 24.50, 'packshots/mimaskot_adulto_carne_3kg.png', TRUE),
        ('7750885026512', 'Comida para Perro Mimaskot Cachorros 1kg', 'Mimaskot', 'Mascotas y Alimento', 12.50, 10.00, 'packshots/mimaskot_cachorro_1kg.png', TRUE),
        ('7613287613356', 'Comida para Perro Dogui Adultos Todas las Razas 1.5kg', 'Dogui', 'Mascotas y Alimento', 17.50, 14.20, 'packshots/dogui_adulto_1_5kg.png', TRUE),
        ('2050044506523', 'Tripack Sobre Dog Chow Adultos Carne 3x100g', 'Dog Chow', 'Mascotas y Alimento', 13.50, 10.80, 'packshots/dog_chow_sobre_carne_100g.png', TRUE),
        ('7896029004326', 'Sobre Pedigree Adulto Carne en Salsa 100g', 'Pedigree', 'Mascotas y Alimento', 3.50, 2.70, 'packshots/pedigree_sobre_carne_100g.png', TRUE),
        ('7896029004357', 'Sobre Pedigree Adulto Pollo en Salsa 100g', 'Pedigree', 'Mascotas y Alimento', 3.50, 2.70, 'packshots/pedigree_sobre_pollo_100g.png', TRUE),
        ('23100051048',   'Comida para Perro Pedigree Adulto Carne Bolsa 2kg', 'Pedigree', 'Mascotas y Alimento', 34.00, 27.80, 'packshots/pedigree_adulto_2kg.png', TRUE),
        -- Comida para Gatos
        ('7753176005548', 'Comida para Gato Ricocat Adulto Atún y Sardina 1kg', 'Ricocat', 'Mascotas y Alimento', 14.00, 11.20, 'packshots/ricocat_adulto_1kg.png', TRUE),
        ('7753176007337', 'Paté para Gato Ricocat Adulto Lata 180g', 'Ricocat', 'Mascotas y Alimento', 4.50, 3.50, 'packshots/ricocat_pate_180g.png', TRUE),
        ('7753176003100', 'Sobre Ricocat Trozos Salmón en Salsa 85g', 'Ricocat', 'Mascotas y Alimento', 3.80, 2.95, 'packshots/ricocat_sobre_salmon_85g.png', TRUE),
        -- Bodega Peruana: Menestras, Galletas, Despensa y Hogar
        ('7622201714819', 'Galletas Soda Field Clásica Six-Pack x6', 'Field', 'Panadería y Desayuno', 3.50, 2.75, 'packshots/galleta_soda_field_x6.png', TRUE),
        ('7622202232756', 'Galletas Saladas Ritz Clásica 70g', 'Ritz', 'Snacks y Piqueos', 2.00, 1.50, 'packshots/galleta_ritz_70g.png', TRUE),
        ('7613035803138', 'Galletas Morochas Nestlé Six-Pack x6', 'Nestlé', 'Golosinas y Chocolates', 4.80, 3.80, 'packshots/galleta_morochas_x6.png', TRUE),
        ('38000184888',   'Papas Pringles Original Lata 104g', 'Pringles', 'Snacks y Piqueos', 9.50, 7.50, 'packshots/pringles_original_104g.png', TRUE),
        ('7750243049566', 'Mostaza AlaCena Doypack 220g', 'AlaCena', 'Abarrotes y Despensa', 4.80, 3.80, 'packshots/mostaza_alacena.png', TRUE),
        ('7753121001892', 'Vinagre Tinto Venturo Botella 600ml', 'Venturo', 'Abarrotes y Despensa', 5.00, 3.90, 'packshots/vinagre_tinto_venturo_600ml.png', TRUE),
        ('7758003000161', 'Lenteja Costeño Bolsa 500g', 'Costeño', 'Abarrotes y Despensa', 5.20, 4.10, 'packshots/lenteja_costeno_500g.png', TRUE),
        ('7755139542183', 'Frijol Canario Costeño Bolsa 500g', 'Costeño', 'Abarrotes y Despensa', 7.80, 6.30, 'packshots/frijol_canario_costeno_500g.png', TRUE),
        ('7758003087193', 'Arveja Partida Costeño Bolsa 500g', 'Costeño', 'Abarrotes y Despensa', 3.80, 2.95, 'packshots/arveja_partida_costeno_500g.png', TRUE),
        ('7758003370110', 'Garbanzo Costeño Bolsa 500g', 'Costeño', 'Abarrotes y Despensa', 6.20, 4.95, 'packshots/garbanzo_costeno_500g.png', TRUE),
        ('7750243227247', 'Harina Preparada Blanca Flor Bolsa 1kg', 'Blanca Flor', 'Abarrotes y Despensa', 7.50, 6.00, 'packshots/harina_blanca_flor_1kg.png', TRUE),
        ('7613030498698', 'Manjar Blanco Nestlé Doypack 200g', 'Nestlé', 'Panadería y Desayuno', 4.80, 3.80, 'packshots/manjar_nestle_200g.png', TRUE),
        ('7750151009614', 'Yogur Frutado Laive Fresa Botella 800g', 'Laive', 'Lácteos y Derivados', 8.50, 6.80, 'packshots/yogur_laive_fresa_800g.png', TRUE),
        ('8445291642126', 'Mini Panetón D''Onofrio Bolsa 80g', 'D''Onofrio', 'Panadería y Desayuno', 4.20, 3.30, 'packshots/mini_paneton_donofrio_80g.png', TRUE),
        ('7501032938215', 'Ambientador Glade Aerosol Campos de Lavanda 400ml', 'Glade', 'Limpieza y Cuidado del Hogar', 11.50, 9.20, 'packshots/ambientador_glade_lavanda.png', TRUE)
    ON CONFLICT (codigo_barras) DO UPDATE SET
        imagen_url = EXCLUDED.imagen_url,
        activo = TRUE;

    -- 4. Sembrar los 32 productos en Bodega KARLIZ con stock comercial inicial visible
    SELECT id_bodega INTO v_bodega_id
    FROM bodegas
    WHERE id_bodega = 1 OR nombre_comercial ILIKE '%KARLIZ%'
    ORDER BY id_bodega ASC
    LIMIT 1;

    IF v_bodega_id IS NOT NULL THEN
        FOR v_item IN
            SELECT * FROM (VALUES
                ('7753176005159', 'Comida para Perro Ricocan Adulto Raza Pequeña Cordero 1kg', 'Ricocan', 'Mascotas y Alimento', 11.50, 9.20, 'packshots/ricocan_cordero_1kg.png', 18.000),
                ('7753176001434', 'Comida para Perro Ricocan Adulto Multisabores 1kg', 'Ricocan', 'Mascotas y Alimento', 11.50, 9.20, 'packshots/ricocan_adulto_multi_1kg.png', 18.000),
                ('7753176004107', 'Comida para Perro Ricocan Cachorros Carne y Leche 1kg', 'Ricocan', 'Mascotas y Alimento', 11.90, 9.50, 'packshots/ricocan_cachorro_1kg.png', 16.000),
                ('7753176005104', 'Paté para Perro Ricocan Adulto Cordero Lata 330g', 'Ricocan', 'Mascotas y Alimento', 5.50, 4.30, 'packshots/ricocan_pate_cordero_330g.png', 24.000),
                ('7753176000567', 'Paté para Perro Ricocan Cachorro Lata 330g', 'Ricocan', 'Mascotas y Alimento', 5.50, 4.30, 'packshots/ricocan_pate_cachorro_330g.png', 20.000),
                ('7753176003049', 'Sobre Ricocan Trocitos en Salsa Cordero 100g', 'Ricocan', 'Mascotas y Alimento', 3.80, 2.95, 'packshots/ricocan_sobre_cordero_100g.png', 30.000),
                ('7750885026376', 'Comida para Perro Mimaskot Adulto Carne 1kg', 'Mimaskot', 'Mascotas y Alimento', 12.50, 10.00, 'packshots/mimaskot_adulto_carne_1kg.png', 16.000),
                ('7750885026345', 'Comida para Perro Mimaskot Adulto Carne Bolsa 3kg', 'Mimaskot', 'Mascotas y Alimento', 29.90, 24.50, 'packshots/mimaskot_adulto_carne_3kg.png', 10.000),
                ('7750885026512', 'Comida para Perro Mimaskot Cachorros 1kg', 'Mimaskot', 'Mascotas y Alimento', 12.50, 10.00, 'packshots/mimaskot_cachorro_1kg.png', 14.000),
                ('7613287613356', 'Comida para Perro Dogui Adultos Todas las Razas 1.5kg', 'Dogui', 'Mascotas y Alimento', 17.50, 14.20, 'packshots/dogui_adulto_1_5kg.png', 14.000),
                ('2050044506523', 'Tripack Sobre Dog Chow Adultos Carne 3x100g', 'Dog Chow', 'Mascotas y Alimento', 13.50, 10.80, 'packshots/dog_chow_sobre_carne_100g.png', 16.000),
                ('7896029004326', 'Sobre Pedigree Adulto Carne en Salsa 100g', 'Pedigree', 'Mascotas y Alimento', 3.50, 2.70, 'packshots/pedigree_sobre_carne_100g.png', 36.000),
                ('7896029004357', 'Sobre Pedigree Adulto Pollo en Salsa 100g', 'Pedigree', 'Mascotas y Alimento', 3.50, 2.70, 'packshots/pedigree_sobre_pollo_100g.png', 36.000),
                ('23100051048',   'Comida para Perro Pedigree Adulto Carne Bolsa 2kg', 'Pedigree', 'Mascotas y Alimento', 34.00, 27.80, 'packshots/pedigree_adulto_2kg.png', 10.000),
                ('7753176005548', 'Comida para Gato Ricocat Adulto Atún y Sardina 1kg', 'Ricocat', 'Mascotas y Alimento', 14.00, 11.20, 'packshots/ricocat_adulto_1kg.png', 16.000),
                ('7753176007337', 'Paté para Gato Ricocat Adulto Lata 180g', 'Ricocat', 'Mascotas y Alimento', 4.50, 3.50, 'packshots/ricocat_pate_180g.png', 20.000),
                ('7753176003100', 'Sobre Ricocat Trozos Salmón en Salsa 85g', 'Ricocat', 'Mascotas y Alimento', 3.80, 2.95, 'packshots/ricocat_sobre_salmon_85g.png', 28.000),
                ('7622201714819', 'Galletas Soda Field Clásica Six-Pack x6', 'Field', 'Panadería y Desayuno', 3.50, 2.75, 'packshots/galleta_soda_field_x6.png', 24.000),
                ('7622202232756', 'Galletas Saladas Ritz Clásica 70g', 'Ritz', 'Snacks y Piqueos', 2.00, 1.50, 'packshots/galleta_ritz_70g.png', 36.000),
                ('7613035803138', 'Galletas Morochas Nestlé Six-Pack x6', 'Nestlé', 'Golosinas y Chocolates', 4.80, 3.80, 'packshots/galleta_morochas_x6.png', 24.000),
                ('38000184888',   'Papas Pringles Original Lata 104g', 'Pringles', 'Snacks y Piqueos', 9.50, 7.50, 'packshots/pringles_original_104g.png', 16.000),
                ('7750243049566', 'Mostaza AlaCena Doypack 220g', 'AlaCena', 'Abarrotes y Despensa', 4.80, 3.80, 'packshots/mostaza_alacena.png', 20.000),
                ('7753121001892', 'Vinagre Tinto Venturo Botella 600ml', 'Venturo', 'Abarrotes y Despensa', 5.00, 3.90, 'packshots/vinagre_tinto_venturo_600ml.png', 18.000),
                ('7758003000161', 'Lenteja Costeño Bolsa 500g', 'Costeño', 'Abarrotes y Despensa', 5.20, 4.10, 'packshots/lenteja_costeno_500g.png', 24.000),
                ('7755139542183', 'Frijol Canario Costeño Bolsa 500g', 'Costeño', 'Abarrotes y Despensa', 7.80, 6.30, 'packshots/frijol_canario_costeno_500g.png', 20.000),
                ('7758003087193', 'Arveja Partida Costeño Bolsa 500g', 'Costeño', 'Abarrotes y Despensa', 3.80, 2.95, 'packshots/arveja_partida_costeno_500g.png', 24.000),
                ('7758003370110', 'Garbanzo Costeño Bolsa 500g', 'Costeño', 'Abarrotes y Despensa', 6.20, 4.95, 'packshots/garbanzo_costeno_500g.png', 18.000),
                ('7750243227247', 'Harina Preparada Blanca Flor Bolsa 1kg', 'Blanca Flor', 'Abarrotes y Despensa', 7.50, 6.00, 'packshots/harina_blanca_flor_1kg.png', 18.000),
                ('7613030498698', 'Manjar Blanco Nestlé Doypack 200g', 'Nestlé', 'Panadería y Desayuno', 4.80, 3.80, 'packshots/manjar_nestle_200g.png', 20.000),
                ('7750151009614', 'Yogur Frutado Laive Fresa Botella 800g', 'Laive', 'Lácteos y Derivados', 8.50, 6.80, 'packshots/yogur_laive_fresa_800g.png', 14.000),
                ('8445291642126', 'Mini Panetón D''Onofrio Bolsa 80g', 'D''Onofrio', 'Panadería y Desayuno', 4.20, 3.30, 'packshots/mini_paneton_donofrio_80g.png', 24.000),
                ('7501032938215', 'Ambientador Glade Aerosol Campos de Lavanda 400ml', 'Glade', 'Limpieza y Cuidado del Hogar', 11.50, 9.20, 'packshots/ambientador_glade_lavanda.png', 14.000)
            ) AS t(ean, nombre, marca, categoria, pventa, pcosto, img, stock_ini)
        LOOP
            SELECT id_categoria INTO v_cat_id
            FROM categorias
            WHERE id_bodega = v_bodega_id AND LOWER(TRIM(nombre)) = LOWER(TRIM(v_item.categoria))
            LIMIT 1;

            IF v_cat_id IS NULL THEN
                SELECT id_categoria INTO v_cat_id
                FROM categorias
                WHERE id_bodega = v_bodega_id AND estado = TRUE
                ORDER BY id_categoria ASC
                LIMIT 1;
            END IF;

            IF v_cat_id IS NOT NULL AND NOT EXISTS (
                SELECT 1 FROM productos
                WHERE id_bodega = v_bodega_id
                  AND (codigo_barras = v_item.ean OR LOWER(TRIM(nombre)) = LOWER(TRIM(v_item.nombre)))
            ) THEN
                INSERT INTO productos (
                    codigo, codigo_barras, nombre, marca, precio_venta, precio_costo,
                    stock_actual, stock_minimo, controla_vencimiento, imagen_url,
                    id_categoria, id_bodega, estado
                ) VALUES (
                    'PROD-' || v_item.ean,
                    v_item.ean,
                    v_item.nombre,
                    v_item.marca,
                    v_item.pventa,
                    v_item.pcosto,
                    v_item.stock_ini,
                    5.000,
                    FALSE,
                    v_item.img,
                    v_cat_id,
                    v_bodega_id,
                    TRUE
                );
            END IF;
        END LOOP;
    END IF;
END $$;
