-- ==============================================================================
-- Migración v38: Expansión Comercial Ola 6 (+40 productos peruanos de alta
-- rotación con EAN-13 reales y packshots oficiales: Piscos/Vinos/Rones/Cervezas,
-- Energizantes/Tés Helados/Jugos, Cuidado Femenino/Botiquín/Pilas, Chocolates,
-- Galletas, Chicles y Caramelos). 100% idempotente.
-- ==============================================================================

DO $$
DECLARE
    v_bodega_id BIGINT;
    v_cat_id BIGINT;
    v_item RECORD;
BEGIN
    -- 1. Registrar los 40 productos en el Preset Global del SuperAdmin
    INSERT INTO catalogo_starter_pack_global (
        codigo_barras, nombre, marca, categoria, precio_venta, precio_costo, imagen_url, activo
    ) VALUES
        ('7750533001083', 'Pisco Puro Quebranta Tabernero 700ml', 'Tabernero', 'Bebidas Alcohólicas', 41.90, 34.50, 'packshots/pisco_tabernero_quebranta_700ml.png', TRUE),
        ('7758218000024', 'Pisco Santiago Queirolo Acholado 750ml', 'Santiago Queirolo', 'Bebidas Alcohólicas', 28.90, 23.50, 'packshots/pisco_queirolo_acholado_750ml.png', TRUE),
        ('7751738445672', 'Ron Cartavio Black Botella 1 Litro', 'Cartavio', 'Bebidas Alcohólicas', 29.90, 24.50, 'packshots/ron_cartavio_black_1l.png', TRUE),
        ('26964861006', 'Ron Flor de Caña Spresso 750ml', 'Flor de Caña', 'Bebidas Alcohólicas', 46.90, 38.50, 'packshots/ron_flor_de_cana_spresso_750ml.png', TRUE),
        ('7758218000161', 'Vino Santiago Queirolo Borgoña Pack x2 750ml', 'Santiago Queirolo', 'Bebidas Alcohólicas', 28.90, 23.50, 'packshots/vino_queirolo_borgona_x2.png', TRUE),
        ('7804340901057', 'Vino Tinto Carménère Tarapacá Gran Reserva 750ml', 'Tarapacá', 'Bebidas Alcohólicas', 58.90, 48.00, 'packshots/vino_tarapaca_gran_reserva.png', TRUE),
        ('7753749003339', 'Cerveza Cusqueña Trigo Lata 355ml', 'Cusqueña', 'Bebidas Alcohólicas', 5.00, 3.90, 'packshots/cerveza_cusquena_trigo_lata.png', TRUE),
        ('7753749003353', 'Cerveza Cusqueña Negra Lata 355ml', 'Cusqueña', 'Bebidas Alcohólicas', 5.00, 3.90, 'packshots/cerveza_cusquena_negra_lata.png', TRUE),
        ('7750670012270', 'Cerveza Tres Cruces Six-Pack Latas 355ml', 'Tres Cruces', 'Bebidas Alcohólicas', 20.90, 17.00, 'packshots/cerveza_tres_cruces_sixpack.png', TRUE),
        ('7753749008396', 'Cerveza Budweiser Six-Pack Latas 355ml', 'Budweiser', 'Bebidas Alcohólicas', 19.90, 16.20, 'packshots/cerveza_budweiser_sixpack.png', TRUE),
        ('7753749009072', 'Cerveza Pilsen Callao Fresh Botella 305ml', 'Pilsen Callao', 'Bebidas Alcohólicas', 4.00, 3.15, 'packshots/cerveza_pilsen_fresh_305ml.png', TRUE),
        ('849806005860', 'Bebida Alcohólica Four Loko Purple Lata 591ml', 'Four Loko', 'Bebidas Alcohólicas', 13.50, 10.80, 'packshots/four_loko_purple_591ml.png', TRUE),
        ('7755321001481', 'Chilcano Portón Mango Lata 355ml', 'Portón', 'Bebidas Alcohólicas', 7.90, 6.20, 'packshots/porton_chilcano_mango_355ml.png', TRUE),
        ('9002490100094', 'Bebida Energizante Red Bull Lata 250ml', 'Red Bull', 'Gaseosas y Bebidas', 7.50, 5.90, 'packshots/red_bull_250ml.png', TRUE),
        ('70847038672', 'Bebida Energizante Monster Mango Loco Lata 473ml', 'Monster Energy', 'Gaseosas y Bebidas', 8.00, 6.30, 'packshots/monster_mango_loco_473ml.png', TRUE),
        ('7751655000602', 'Bebida Rehidratante Gatorade Mandarina 500ml', 'Gatorade', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/gatorade_mandarina_500ml.png', TRUE),
        ('7750670012478', 'Té Helado Free Tea Durazno 500ml', 'Free Tea', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/free_tea_durazno_500ml.png', TRUE),
        ('7750670012164', 'Té Helado Free Tea Limón 450ml', 'Free Tea', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/free_tea_limon_450ml.png', TRUE),
        ('2050044370162', 'Bebida de Durazno Pulp Botella 1.5 Litros', 'Pulp', 'Gaseosas y Bebidas', 5.50, 4.30, 'packshots/pulp_durazno_15l.png', TRUE),
        ('7751271038515', 'Bebida de Frutas Tampico Citrus Punch 600ml', 'Tampico', 'Gaseosas y Bebidas', 3.20, 2.45, 'packshots/tampico_citrus_600ml.png', TRUE),
        ('7750182002196', 'Gaseosa Schweppes Ginger Ale 1.5 Litros', 'Schweppes', 'Gaseosas y Bebidas', 6.50, 5.10, 'packshots/schweppes_ginger_ale_15l.png', TRUE),
        ('7702026174064', 'Toallas Higiénicas Nosotras Invisible x30', 'Nosotras', 'Cuidado Personal y Dental', 10.50, 8.30, 'packshots/toallas_nosotras_invisible_x30.png', TRUE),
        ('7751493009867', 'Toallas Higiénicas Kotex Nocturna Discreta x12', 'Kotex', 'Cuidado Personal y Dental', 11.50, 9.10, 'packshots/toallas_kotex_nocturna_x12.png', TRUE),
        ('7506306247093', 'Desodorante Dove Original Aerosol 250ml', 'Dove', 'Cuidado Personal y Dental', 22.90, 18.50, 'packshots/desodorante_dove_aerosol_250ml.png', TRUE),
        ('4006000129402', 'Crema Corporal Nivea Regeneración Intensiva 400ml', 'Nivea', 'Cuidado Personal y Dental', 39.90, 32.50, 'packshots/crema_nivea_regeneracion_400ml.png', TRUE),
        ('7759185012362', 'Papel Higiénico Elite Resistente XL Pack x12', 'Elite', 'Cuidado Personal y Dental', 20.50, 16.50, 'packshots/papel_higienico_elite_xl_x12.png', TRUE),
        ('7757310009188', 'Alcohol Medicinal 70° Hersil Botella 1 Litro', 'Hersil', 'Cuidado Personal y Dental', 12.00, 9.50, 'packshots/alcohol_medicinal_hersil_1l.png', TRUE),
        ('7750215091647', 'Agua Oxigenada Portugal 10V Botella 1 Litro', 'Portugal', 'Cuidado Personal y Dental', 6.90, 5.40, 'packshots/agua_oxigenada_portugal_1l.png', TRUE),
        ('7751370000086', 'Algodón Hidrófilo en Zig Zag Family Care 100g', 'Family Care', 'Cuidado Personal y Dental', 6.20, 4.80, 'packshots/algodon_hidrofilo_100g.png', TRUE),
        ('7702003469305', 'Curitas Transpiel Caja x20 unidades', 'Curitas', 'Cuidado Personal y Dental', 11.50, 9.00, 'packshots/curitas_transpiel_x20.png', TRUE),
        ('41333588640', 'Pilas Alcalinas Duracell AA Pack x8', 'Duracell', 'Limpieza y Cuidado del Hogar', 25.90, 20.80, 'packshots/pilas_duracell_aa_x8.png', TRUE),
        ('41333424019', 'Pilas Alcalinas Duracell AAA Pack x4', 'Duracell', 'Limpieza y Cuidado del Hogar', 15.50, 12.40, 'packshots/pilas_duracell_aaa_x4.png', TRUE),
        ('7506105616076', 'Chicle Trident Freshmint Botella x18', 'Trident', 'Golosinas y Chocolates', 4.70, 3.65, 'packshots/chicle_trident_freshmint_x18.png', TRUE),
        ('7613031328536', 'Beso de Moza Vainilla Nestlé Caja x20', 'Nestlé', 'Golosinas y Chocolates', 24.50, 19.80, 'packshots/beso_de_moza_caja_x20.png', TRUE),
        ('7758102004947', 'Chupete Globo Pop Surtido Bolsa x24', 'Globo Pop', 'Golosinas y Chocolates', 8.20, 6.40, 'packshots/chupete_globo_pop_x24.png', TRUE),
        ('7750885024860', 'Chocolate con Almendras Vizzio Costa 19.2g', 'Costa', 'Golosinas y Chocolates', 1.70, 1.25, 'packshots/chocolate_vizzio_costa.png', TRUE),
        ('7750243031318', 'Galletas Glacitas Toffee Six-Pack', 'Victoria', 'Golosinas y Chocolates', 4.20, 3.30, 'packshots/galleta_glacitas_toffee_x6.png', TRUE),
        ('7750243077484', 'Galletas Tentación Chocolate Six-Pack', 'Victoria', 'Golosinas y Chocolates', 4.90, 3.85, 'packshots/galleta_tentacion_choc_x6.png', TRUE),
        ('7750885434645', 'Wafers Nik Costa Chocolate Pack x6', 'Costa', 'Golosinas y Chocolates', 3.50, 2.75, 'packshots/wafer_nik_chocolate_x6.png', TRUE),
        ('7750885003681', 'Caramelos Ambrosoli Cocoroko Limón Bolsa 350g', 'Ambrosoli', 'Golosinas y Chocolates', 8.50, 6.70, 'packshots/caramelos_ambrosoli_limon_350g.png', TRUE)
    ON CONFLICT (codigo_barras) DO UPDATE SET
        imagen_url = EXCLUDED.imagen_url,
        activo = TRUE;

    -- 2. Sembrar los 40 productos en Bodega KARLIZ con stock comercial inicial visible
    SELECT id_bodega INTO v_bodega_id
    FROM bodegas
    WHERE id_bodega = 1 OR nombre_comercial ILIKE '%KARLIZ%'
    ORDER BY id_bodega ASC
    LIMIT 1;

    IF v_bodega_id IS NOT NULL THEN
        FOR v_item IN
            SELECT * FROM (VALUES
                ('7750533001083', 'Pisco Puro Quebranta Tabernero 700ml', 'Tabernero', 'Bebidas Alcohólicas', 41.90, 34.50, 'packshots/pisco_tabernero_quebranta_700ml.png', 8.000),
                ('7758218000024', 'Pisco Santiago Queirolo Acholado 750ml', 'Santiago Queirolo', 'Bebidas Alcohólicas', 28.90, 23.50, 'packshots/pisco_queirolo_acholado_750ml.png', 10.000),
                ('7751738445672', 'Ron Cartavio Black Botella 1 Litro', 'Cartavio', 'Bebidas Alcohólicas', 29.90, 24.50, 'packshots/ron_cartavio_black_1l.png', 10.000),
                ('26964861006', 'Ron Flor de Caña Spresso 750ml', 'Flor de Caña', 'Bebidas Alcohólicas', 46.90, 38.50, 'packshots/ron_flor_de_cana_spresso_750ml.png', 6.000),
                ('7758218000161', 'Vino Santiago Queirolo Borgoña Pack x2 750ml', 'Santiago Queirolo', 'Bebidas Alcohólicas', 28.90, 23.50, 'packshots/vino_queirolo_borgona_x2.png', 10.000),
                ('7804340901057', 'Vino Tinto Carménère Tarapacá Gran Reserva 750ml', 'Tarapacá', 'Bebidas Alcohólicas', 58.90, 48.00, 'packshots/vino_tarapaca_gran_reserva.png', 6.000),
                ('7753749003339', 'Cerveza Cusqueña Trigo Lata 355ml', 'Cusqueña', 'Bebidas Alcohólicas', 5.00, 3.90, 'packshots/cerveza_cusquena_trigo_lata.png', 24.000),
                ('7753749003353', 'Cerveza Cusqueña Negra Lata 355ml', 'Cusqueña', 'Bebidas Alcohólicas', 5.00, 3.90, 'packshots/cerveza_cusquena_negra_lata.png', 24.000),
                ('7750670012270', 'Cerveza Tres Cruces Six-Pack Latas 355ml', 'Tres Cruces', 'Bebidas Alcohólicas', 20.90, 17.00, 'packshots/cerveza_tres_cruces_sixpack.png', 12.000),
                ('7753749008396', 'Cerveza Budweiser Six-Pack Latas 355ml', 'Budweiser', 'Bebidas Alcohólicas', 19.90, 16.20, 'packshots/cerveza_budweiser_sixpack.png', 12.000),
                ('7753749009072', 'Cerveza Pilsen Callao Fresh Botella 305ml', 'Pilsen Callao', 'Bebidas Alcohólicas', 4.00, 3.15, 'packshots/cerveza_pilsen_fresh_305ml.png', 24.000),
                ('849806005860', 'Bebida Alcohólica Four Loko Purple Lata 591ml', 'Four Loko', 'Bebidas Alcohólicas', 13.50, 10.80, 'packshots/four_loko_purple_591ml.png', 14.000),
                ('7755321001481', 'Chilcano Portón Mango Lata 355ml', 'Portón', 'Bebidas Alcohólicas', 7.90, 6.20, 'packshots/porton_chilcano_mango_355ml.png', 18.000),
                ('9002490100094', 'Bebida Energizante Red Bull Lata 250ml', 'Red Bull', 'Gaseosas y Bebidas', 7.50, 5.90, 'packshots/red_bull_250ml.png', 24.000),
                ('70847038672', 'Bebida Energizante Monster Mango Loco Lata 473ml', 'Monster Energy', 'Gaseosas y Bebidas', 8.00, 6.30, 'packshots/monster_mango_loco_473ml.png', 18.000),
                ('7751655000602', 'Bebida Rehidratante Gatorade Mandarina 500ml', 'Gatorade', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/gatorade_mandarina_500ml.png', 24.000),
                ('7750670012478', 'Té Helado Free Tea Durazno 500ml', 'Free Tea', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/free_tea_durazno_500ml.png', 24.000),
                ('7750670012164', 'Té Helado Free Tea Limón 450ml', 'Free Tea', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/free_tea_limon_450ml.png', 24.000),
                ('2050044370162', 'Bebida de Durazno Pulp Botella 1.5 Litros', 'Pulp', 'Gaseosas y Bebidas', 5.50, 4.30, 'packshots/pulp_durazno_15l.png', 16.000),
                ('7751271038515', 'Bebida de Frutas Tampico Citrus Punch 600ml', 'Tampico', 'Gaseosas y Bebidas', 3.20, 2.45, 'packshots/tampico_citrus_600ml.png', 20.000),
                ('7750182002196', 'Gaseosa Schweppes Ginger Ale 1.5 Litros', 'Schweppes', 'Gaseosas y Bebidas', 6.50, 5.10, 'packshots/schweppes_ginger_ale_15l.png', 14.000),
                ('7702026174064', 'Toallas Higiénicas Nosotras Invisible x30', 'Nosotras', 'Cuidado Personal y Dental', 10.50, 8.30, 'packshots/toallas_nosotras_invisible_x30.png', 14.000),
                ('7751493009867', 'Toallas Higiénicas Kotex Nocturna Discreta x12', 'Kotex', 'Cuidado Personal y Dental', 11.50, 9.10, 'packshots/toallas_kotex_nocturna_x12.png', 14.000),
                ('7506306247093', 'Desodorante Dove Original Aerosol 250ml', 'Dove', 'Cuidado Personal y Dental', 22.90, 18.50, 'packshots/desodorante_dove_aerosol_250ml.png', 12.000),
                ('4006000129402', 'Crema Corporal Nivea Regeneración Intensiva 400ml', 'Nivea', 'Cuidado Personal y Dental', 39.90, 32.50, 'packshots/crema_nivea_regeneracion_400ml.png', 8.000),
                ('7759185012362', 'Papel Higiénico Elite Resistente XL Pack x12', 'Elite', 'Cuidado Personal y Dental', 20.50, 16.50, 'packshots/papel_higienico_elite_xl_x12.png', 12.000),
                ('7757310009188', 'Alcohol Medicinal 70° Hersil Botella 1 Litro', 'Hersil', 'Cuidado Personal y Dental', 12.00, 9.50, 'packshots/alcohol_medicinal_hersil_1l.png', 14.000),
                ('7750215091647', 'Agua Oxigenada Portugal 10V Botella 1 Litro', 'Portugal', 'Cuidado Personal y Dental', 6.90, 5.40, 'packshots/agua_oxigenada_portugal_1l.png', 16.000),
                ('7751370000086', 'Algodón Hidrófilo en Zig Zag Family Care 100g', 'Family Care', 'Cuidado Personal y Dental', 6.20, 4.80, 'packshots/algodon_hidrofilo_100g.png', 18.000),
                ('7702003469305', 'Curitas Transpiel Caja x20 unidades', 'Curitas', 'Cuidado Personal y Dental', 11.50, 9.00, 'packshots/curitas_transpiel_x20.png', 16.000),
                ('41333588640', 'Pilas Alcalinas Duracell AA Pack x8', 'Duracell', 'Limpieza y Cuidado del Hogar', 25.90, 20.80, 'packshots/pilas_duracell_aa_x8.png', 12.000),
                ('41333424019', 'Pilas Alcalinas Duracell AAA Pack x4', 'Duracell', 'Limpieza y Cuidado del Hogar', 15.50, 12.40, 'packshots/pilas_duracell_aaa_x4.png', 14.000),
                ('7506105616076', 'Chicle Trident Freshmint Botella x18', 'Trident', 'Golosinas y Chocolates', 4.70, 3.65, 'packshots/chicle_trident_freshmint_x18.png', 24.000),
                ('7613031328536', 'Beso de Moza Vainilla Nestlé Caja x20', 'Nestlé', 'Golosinas y Chocolates', 24.50, 19.80, 'packshots/beso_de_moza_caja_x20.png', 10.000),
                ('7758102004947', 'Chupete Globo Pop Surtido Bolsa x24', 'Globo Pop', 'Golosinas y Chocolates', 8.20, 6.40, 'packshots/chupete_globo_pop_x24.png', 16.000),
                ('7750885024860', 'Chocolate con Almendras Vizzio Costa 19.2g', 'Costa', 'Golosinas y Chocolates', 1.70, 1.25, 'packshots/chocolate_vizzio_costa.png', 36.000),
                ('7750243031318', 'Galletas Glacitas Toffee Six-Pack', 'Victoria', 'Golosinas y Chocolates', 4.20, 3.30, 'packshots/galleta_glacitas_toffee_x6.png', 24.000),
                ('7750243077484', 'Galletas Tentación Chocolate Six-Pack', 'Victoria', 'Golosinas y Chocolates', 4.90, 3.85, 'packshots/galleta_tentacion_choc_x6.png', 24.000),
                ('7750885434645', 'Wafers Nik Costa Chocolate Pack x6', 'Costa', 'Golosinas y Chocolates', 3.50, 2.75, 'packshots/wafer_nik_chocolate_x6.png', 24.000),
                ('7750885003681', 'Caramelos Ambrosoli Cocoroko Limón Bolsa 350g', 'Ambrosoli', 'Golosinas y Chocolates', 8.50, 6.70, 'packshots/caramelos_ambrosoli_limon_350g.png', 16.000)
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
