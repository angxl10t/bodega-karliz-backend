-- ==============================================================================
-- Migración v37: Expansión Comercial Ola 5 (+35 productos peruanos de alta
-- rotación con EAN-13 reales y packshots oficiales: Pañales y Bebé, Café e
-- Infusiones, Condimentos/Caldos/Conservas, Cuidado Personal/Limpieza y
-- más Mascotas). 100% idempotente.
-- ==============================================================================

DO $$
DECLARE
    v_bodega_id BIGINT;
    v_cat_id BIGINT;
    v_item RECORD;
BEGIN
    -- 1. Registrar los 35 productos en el Preset Global del SuperAdmin
    INSERT INTO catalogo_starter_pack_global (
        codigo_barras, nombre, marca, categoria, precio_venta, precio_costo, imagen_url, activo
    ) VALUES
        -- Cuidado Personal, Dental y Bebé
        ('7751493010139', 'Pañales Huggies Natural Care Talla G x66', 'Huggies', 'Cuidado Personal y Dental', 59.90, 49.00, 'packshots/panales_huggies_g.png', TRUE),
        ('7759185011327', 'Pañales Babysec Super Premium Talla G x66', 'Babysec', 'Cuidado Personal y Dental', 51.90, 42.50, 'packshots/panales_babysec_g.png', TRUE),
        ('7702031291565', 'Shampoo Original Johnson''s Baby 200ml', 'Johnson''s', 'Cuidado Personal y Dental', 19.50, 15.80, 'packshots/shampoo_johnsons_baby.png', TRUE),
        ('7702010921681', 'Jabón Protex Antibacterial Avena Pack x6', 'Protex', 'Cuidado Personal y Dental', 21.50, 17.50, 'packshots/jabon_protex_avena_x6.png', TRUE),
        ('7500435116800', 'Máquina de Afeitar Gillette Prestobarba 3', 'Gillette', 'Cuidado Personal y Dental', 21.50, 17.20, 'packshots/gillette_prestobarba3.png', TRUE),
        ('7506306237315', 'Shampoo Sedal Ceramidas 340ml', 'Sedal', 'Cuidado Personal y Dental', 12.50, 10.00, 'packshots/shampoo_sedal_ceramidas.png', TRUE),
        ('7702035800664', 'Enjuague Bucal Listerine Cool Mint 180ml', 'Listerine', 'Cuidado Personal y Dental', 9.90, 7.90, 'packshots/listerine_cool_mint.png', TRUE),
        ('7804653341656', 'Papel Toalla Doble Hoja Gigante', 'Home Care', 'Cuidado Personal y Dental', 9.50, 7.60, 'packshots/papel_toalla_gigante.png', TRUE),
        -- Café, Infusiones, Desayuno y Lácteos
        ('7750463001733', 'Café Molido Altomayo Clásico 450g', 'Altomayo', 'Panadería y Desayuno', 29.90, 24.50, 'packshots/cafe_altomayo_450g.png', TRUE),
        ('7752087129305', 'Café Instantáneo Kirma Clásico 180g', 'Kirma', 'Panadería y Desayuno', 23.90, 19.50, 'packshots/cafe_kirma_180g.png', TRUE),
        ('8445292127240', 'Cebada Instantánea Ecco 170g', 'Ecco', 'Panadería y Desayuno', 14.50, 11.80, 'packshots/cebada_ecco_170g.png', TRUE),
        ('7752748011963', 'Cocoa Winter''s Lata 360g', 'Winter''s', 'Panadería y Desayuno', 33.90, 27.80, 'packshots/cocoa_winters_360g.png', TRUE),
        ('7758574004605', 'Avena Quaker Tradicional Bolsa 200g', 'Quaker', 'Panadería y Desayuno', 4.50, 3.50, 'packshots/avena_quaker_200g.png', TRUE),
        ('7759826001670', 'Cereal Ángel Flakes Bolsa 1kg', 'Ángel', 'Panadería y Desayuno', 15.50, 12.60, 'packshots/cereal_angel_flakes_1kg.png', TRUE),
        ('2050000442971', 'Mermelada Fanny Fresa Pote 700g', 'Fanny', 'Panadería y Desayuno', 12.50, 10.00, 'packshots/mermelada_fanny_700g.png', TRUE),
        ('7751271031653', 'Mantequilla con Sal Gloria Barra 90g', 'Gloria', 'Lácteos y Derivados', 6.50, 5.20, 'packshots/mantequilla_gloria_90g.png', TRUE),
        ('7750477080007', 'Té Canela y Clavo McColin''s Caja x100', 'McColin''s', 'Panadería y Desayuno', 11.50, 9.20, 'packshots/te_mccolins_canela_clavo.png', TRUE),
        -- Condimentos, Caldos, Conservas y Despensa
        ('7754487000000', 'Sazonador Ajinomoto Frasco 100g', 'Ajinomoto', 'Abarrotes y Despensa', 10.50, 8.40, 'packshots/ajinomoto_sazonador_100g.png', TRUE),
        ('7754487000345', 'Caldo Doña Gusta Gallina Pack x6', 'Doña Gusta', 'Abarrotes y Despensa', 2.50, 1.90, 'packshots/dona_gusta_gallina_x6.png', TRUE),
        ('7754487000352', 'Caldo Doña Gusta Carne Pack x6', 'Doña Gusta', 'Abarrotes y Despensa', 2.50, 1.90, 'packshots/dona_gusta_carne_x6.png', TRUE),
        ('7753121000383', 'Pimienta Negra Molida Sibarita 40g', 'Sibarita', 'Abarrotes y Despensa', 9.90, 7.90, 'packshots/sibarita_pimienta_40g.png', TRUE),
        ('7753121004015', 'Comino Molido Sibarita Pack x6 Sobres', 'Sibarita', 'Abarrotes y Despensa', 4.20, 3.30, 'packshots/sibarita_comino_x6.png', TRUE),
        ('7753121003855', 'Palillo Sibarita Sobre 57g', 'Sibarita', 'Abarrotes y Despensa', 2.50, 1.90, 'packshots/sibarita_palillo_57g.png', TRUE),
        ('7750885003469', 'Salsa de Tomate Pomarola Doypack 145g', 'Pomarola', 'Abarrotes y Despensa', 1.80, 1.35, 'packshots/salsa_pomarola_145g.png', TRUE),
        ('7751158187893', 'Duraznos en Almíbar Aconcagua Lata 820g', 'Aconcagua', 'Abarrotes y Despensa', 9.50, 7.60, 'packshots/duraznos_aconcagua_820g.png', TRUE),
        ('7755139002816', 'Arroz Superior Paisana Bolsa 1kg', 'Paisana', 'Abarrotes y Despensa', 4.50, 3.70, 'packshots/arroz_paisana_1kg.png', TRUE),
        ('2050044298305', 'Twopack Aceite Vegetal Primor Clásico 2x900ml', 'Primor', 'Abarrotes y Despensa', 17.50, 14.50, 'packshots/aceite_primor_twopack.png', TRUE),
        -- Limpieza y Cuidado del Hogar
        ('7750243057448', 'Jabón para Ropa Bolívar Limón 190g', 'Bolívar', 'Limpieza y Cuidado del Hogar', 3.20, 2.50, 'packshots/jabon_bolivar_limon_190g.png', TRUE),
        ('7706800766513', 'Insecticida Raid Aerosol Acción Total', 'Raid', 'Limpieza y Cuidado del Hogar', 18.50, 15.00, 'packshots/insecticida_raid_aerosol.png', TRUE),
        ('7751851008167', 'Desinfectante Limpiador Sapolio Pino Galón 3.78L', 'Sapolio', 'Limpieza y Cuidado del Hogar', 24.50, 19.80, 'packshots/desinfectante_sapolio_pino.png', TRUE),
        ('7750243079136', 'Detergente Marsella Amazonía Tropical 4kg', 'Marsella', 'Limpieza y Cuidado del Hogar', 32.90, 27.00, 'packshots/detergente_marsella_4kg.png', TRUE),
        -- Más Mascotas y Alimento
        ('7613287613455', 'Comida para Perro Dogui Adulto Saco 8kg', 'Dogui', 'Mascotas y Alimento', 68.00, 56.00, 'packshots/dogui_adulto_8kg.png', TRUE),
        ('7896029022252', 'Sobre Pedigree Cachorro Pollo en Salsa 100g', 'Pedigree', 'Mascotas y Alimento', 3.80, 2.95, 'packshots/pedigree_cachorro_pollo_100g.png', TRUE),
        ('7896029046609', 'Sobre Whiskas Gato Adulto Carne 85g', 'Whiskas', 'Mascotas y Alimento', 3.50, 2.70, 'packshots/whiskas_sobre_carne_85g.png', TRUE),
        ('7891000120781', 'Sobre Purina Felix Gato Adulto Atún 85g', 'Felix', 'Mascotas y Alimento', 4.20, 3.30, 'packshots/felix_sobre_atun_85g.png', TRUE)
    ON CONFLICT (codigo_barras) DO UPDATE SET
        imagen_url = EXCLUDED.imagen_url,
        activo = TRUE;

    -- 2. Sembrar los 35 productos en Bodega KARLIZ con stock comercial inicial visible
    SELECT id_bodega INTO v_bodega_id
    FROM bodegas
    WHERE id_bodega = 1 OR nombre_comercial ILIKE '%KARLIZ%'
    ORDER BY id_bodega ASC
    LIMIT 1;

    IF v_bodega_id IS NOT NULL THEN
        FOR v_item IN
            SELECT * FROM (VALUES
                ('7751493010139', 'Pañales Huggies Natural Care Talla G x66', 'Huggies', 'Cuidado Personal y Dental', 59.90, 49.00, 'packshots/panales_huggies_g.png', 10.000),
                ('7759185011327', 'Pañales Babysec Super Premium Talla G x66', 'Babysec', 'Cuidado Personal y Dental', 51.90, 42.50, 'packshots/panales_babysec_g.png', 10.000),
                ('7702031291565', 'Shampoo Original Johnson''s Baby 200ml', 'Johnson''s', 'Cuidado Personal y Dental', 19.50, 15.80, 'packshots/shampoo_johnsons_baby.png', 12.000),
                ('7702010921681', 'Jabón Protex Antibacterial Avena Pack x6', 'Protex', 'Cuidado Personal y Dental', 21.50, 17.50, 'packshots/jabon_protex_avena_x6.png', 14.000),
                ('7500435116800', 'Máquina de Afeitar Gillette Prestobarba 3', 'Gillette', 'Cuidado Personal y Dental', 21.50, 17.20, 'packshots/gillette_prestobarba3.png', 12.000),
                ('7506306237315', 'Shampoo Sedal Ceramidas 340ml', 'Sedal', 'Cuidado Personal y Dental', 12.50, 10.00, 'packshots/shampoo_sedal_ceramidas.png', 14.000),
                ('7702035800664', 'Enjuague Bucal Listerine Cool Mint 180ml', 'Listerine', 'Cuidado Personal y Dental', 9.90, 7.90, 'packshots/listerine_cool_mint.png', 16.000),
                ('7804653341656', 'Papel Toalla Doble Hoja Gigante', 'Home Care', 'Cuidado Personal y Dental', 9.50, 7.60, 'packshots/papel_toalla_gigante.png', 18.000),
                ('7750463001733', 'Café Molido Altomayo Clásico 450g', 'Altomayo', 'Panadería y Desayuno', 29.90, 24.50, 'packshots/cafe_altomayo_450g.png', 12.000),
                ('7752087129305', 'Café Instantáneo Kirma Clásico 180g', 'Kirma', 'Panadería y Desayuno', 23.90, 19.50, 'packshots/cafe_kirma_180g.png', 14.000),
                ('8445292127240', 'Cebada Instantánea Ecco 170g', 'Ecco', 'Panadería y Desayuno', 14.50, 11.80, 'packshots/cebada_ecco_170g.png', 16.000),
                ('7752748011963', 'Cocoa Winter''s Lata 360g', 'Winter''s', 'Panadería y Desayuno', 33.90, 27.80, 'packshots/cocoa_winters_360g.png', 12.000),
                ('7758574004605', 'Avena Quaker Tradicional Bolsa 200g', 'Quaker', 'Panadería y Desayuno', 4.50, 3.50, 'packshots/avena_quaker_200g.png', 24.000),
                ('7759826001670', 'Cereal Ángel Flakes Bolsa 1kg', 'Ángel', 'Panadería y Desayuno', 15.50, 12.60, 'packshots/cereal_angel_flakes_1kg.png', 14.000),
                ('2050000442971', 'Mermelada Fanny Fresa Pote 700g', 'Fanny', 'Panadería y Desayuno', 12.50, 10.00, 'packshots/mermelada_fanny_700g.png', 14.000),
                ('7751271031653', 'Mantequilla con Sal Gloria Barra 90g', 'Gloria', 'Lácteos y Derivados', 6.50, 5.20, 'packshots/mantequilla_gloria_90g.png', 24.000),
                ('7750477080007', 'Té Canela y Clavo McColin''s Caja x100', 'McColin''s', 'Panadería y Desayuno', 11.50, 9.20, 'packshots/te_mccolins_canela_clavo.png', 16.000),
                ('7754487000000', 'Sazonador Ajinomoto Frasco 100g', 'Ajinomoto', 'Abarrotes y Despensa', 10.50, 8.40, 'packshots/ajinomoto_sazonador_100g.png', 18.000),
                ('7754487000345', 'Caldo Doña Gusta Gallina Pack x6', 'Doña Gusta', 'Abarrotes y Despensa', 2.50, 1.90, 'packshots/dona_gusta_gallina_x6.png', 36.000),
                ('7754487000352', 'Caldo Doña Gusta Carne Pack x6', 'Doña Gusta', 'Abarrotes y Despensa', 2.50, 1.90, 'packshots/dona_gusta_carne_x6.png', 36.000),
                ('7753121000383', 'Pimienta Negra Molida Sibarita 40g', 'Sibarita', 'Abarrotes y Despensa', 9.90, 7.90, 'packshots/sibarita_pimienta_40g.png', 18.000),
                ('7753121004015', 'Comino Molido Sibarita Pack x6 Sobres', 'Sibarita', 'Abarrotes y Despensa', 4.20, 3.30, 'packshots/sibarita_comino_x6.png', 24.000),
                ('7753121003855', 'Palillo Sibarita Sobre 57g', 'Sibarita', 'Abarrotes y Despensa', 2.50, 1.90, 'packshots/sibarita_palillo_57g.png', 24.000),
                ('7750885003469', 'Salsa de Tomate Pomarola Doypack 145g', 'Pomarola', 'Abarrotes y Despensa', 1.80, 1.35, 'packshots/salsa_pomarola_145g.png', 36.000),
                ('7751158187893', 'Duraznos en Almíbar Aconcagua Lata 820g', 'Aconcagua', 'Abarrotes y Despensa', 9.50, 7.60, 'packshots/duraznos_aconcagua_820g.png', 14.000),
                ('7755139002816', 'Arroz Superior Paisana Bolsa 1kg', 'Paisana', 'Abarrotes y Despensa', 4.50, 3.70, 'packshots/arroz_paisana_1kg.png', 24.000),
                ('2050044298305', 'Twopack Aceite Vegetal Primor Clásico 2x900ml', 'Primor', 'Abarrotes y Despensa', 17.50, 14.50, 'packshots/aceite_primor_twopack.png', 14.000),
                ('7750243057448', 'Jabón para Ropa Bolívar Limón 190g', 'Bolívar', 'Limpieza y Cuidado del Hogar', 3.20, 2.50, 'packshots/jabon_bolivar_limon_190g.png', 24.000),
                ('7706800766513', 'Insecticida Raid Aerosol Acción Total', 'Raid', 'Limpieza y Cuidado del Hogar', 18.50, 15.00, 'packshots/insecticida_raid_aerosol.png', 12.000),
                ('7751851008167', 'Desinfectante Limpiador Sapolio Pino Galón 3.78L', 'Sapolio', 'Limpieza y Cuidado del Hogar', 24.50, 19.80, 'packshots/desinfectante_sapolio_pino.png', 10.000),
                ('7750243079136', 'Detergente Marsella Amazonía Tropical 4kg', 'Marsella', 'Limpieza y Cuidado del Hogar', 32.90, 27.00, 'packshots/detergente_marsella_4kg.png', 10.000),
                ('7613287613455', 'Comida para Perro Dogui Adulto Saco 8kg', 'Dogui', 'Mascotas y Alimento', 68.00, 56.00, 'packshots/dogui_adulto_8kg.png', 8.000),
                ('7896029022252', 'Sobre Pedigree Cachorro Pollo en Salsa 100g', 'Pedigree', 'Mascotas y Alimento', 3.80, 2.95, 'packshots/pedigree_cachorro_pollo_100g.png', 30.000),
                ('7896029046609', 'Sobre Whiskas Gato Adulto Carne 85g', 'Whiskas', 'Mascotas y Alimento', 3.50, 2.70, 'packshots/whiskas_sobre_carne_85g.png', 36.000),
                ('7891000120781', 'Sobre Purina Felix Gato Adulto Atún 85g', 'Felix', 'Mascotas y Alimento', 4.20, 3.30, 'packshots/felix_sobre_atun_85g.png', 30.000)
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
