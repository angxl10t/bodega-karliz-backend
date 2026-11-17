-- ==============================================================================
-- Migración v35: Expansión Comercial Ola 3 (+40 variantes de tamaño, sabor y
-- presentación en las 12 categorías de bodega peruana).
-- 100% idempotente: sincroniza el preset global y enriquece Bodega KARLIZ (ID 1).
-- ==============================================================================

DO $$
DECLARE
    v_bodega_id BIGINT;
    v_cat_id BIGINT;
    v_item RECORD;
BEGIN
    -- 1. Registrar las 40 nuevas variantes en el Preset Global del SuperAdmin
    INSERT INTO catalogo_starter_pack_global (
        codigo_barras, nombre, marca, categoria, precio_venta, precio_costo, imagen_url, activo
    ) VALUES
        -- Gaseosas y Bebidas (Zero 1.5L/3L, aguas 2.5L, jugos personales 300ml)
        ('7750106001126', 'Inca Kola Sin Azúcar Zero 1.5 Litros', 'Inca Kola', 'Gaseosas y Bebidas', 6.50, 5.20, 'packshots/inka_kola.png', TRUE),
        ('7750106001133', 'Inca Kola Sin Azúcar Zero 3 Litros', 'Inca Kola', 'Gaseosas y Bebidas', 12.00, 9.80, 'packshots/inka_kola_3l.png', TRUE),
        ('7750106002123', 'Coca Cola Sin Azúcar Zero 1.5 Litros', 'Coca Cola', 'Gaseosas y Bebidas', 6.50, 5.20, 'packshots/coca_cola.png', TRUE),
        ('7750106002130', 'Coca Cola Sin Azúcar Zero 3 Litros', 'Coca Cola', 'Gaseosas y Bebidas', 12.00, 9.80, 'packshots/coca_cola_3l.png', TRUE),
        ('7750106003038', 'Agua San Luis Sin Gas 2.5 Litros', 'San Luis', 'Gaseosas y Bebidas', 3.50, 2.70, 'packshots/agua_san_luis.png', TRUE),
        ('7750670010047', 'Agua Cielo Sin Gas 2.5 Litros', 'Cielo', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/agua_cielo.png', TRUE),
        ('7750106008057', 'Jugo Frugos del Valle Durazno Botella 300ml', 'Frugos', 'Gaseosas y Bebidas', 1.80, 1.35, 'packshots/frugos_durazno.png', TRUE),
        ('7750106008064', 'Jugo Frugos del Valle Mango Botella 300ml', 'Frugos', 'Gaseosas y Bebidas', 1.80, 1.35, 'packshots/frugos_mango.png', TRUE),
        -- Bebidas Alcohólicas (retornables, personales, six-packs y vino rosé)
        ('7750106006046', 'Cerveza Cusqueña Trigo 620ml Retornable', 'Cusqueña', 'Bebidas Alcohólicas', 7.50, 6.00, 'packshots/cerveza_cusquena.png', TRUE),
        ('7750106006053', 'Cerveza Cusqueña Dorada Six-Pack Botella 310ml', 'Cusqueña', 'Bebidas Alcohólicas', 30.00, 24.50, 'packshots/cerveza_cusquena_dorada.png', TRUE),
        ('7750111006625', 'Cerveza Pilsen Callao Botella Personal 305ml', 'Pilsen Callao', 'Bebidas Alcohólicas', 4.00, 3.15, 'packshots/cerveza_pilsen.png', TRUE),
        ('7891991000833', 'Cerveza Stella Artois Six-Pack Botella 330ml', 'Stella Artois', 'Bebidas Alcohólicas', 36.00, 29.00, 'packshots/cerveza_stella.png', TRUE),
        ('7750170000029', 'Vino Tabernero Rose Semi Seco 750ml', 'Tabernero', 'Bebidas Alcohólicas', 21.00, 16.80, 'packshots/vino_tabernero.png', TRUE),
        -- Snacks y Piqueos (tamaños personales de alta rotación escolar y al paso)
        ('7758574005602', 'Papas Fritas Lay''s Clásicas Personal 42g', 'Lay''s', 'Snacks y Piqueos', 2.00, 1.50, 'packshots/lays_clasicas_140g.png', TRUE),
        ('7758574005619', 'Papas Fritas Lay''s Ondas Personal 42g', 'Lay''s', 'Snacks y Piqueos', 2.00, 1.50, 'packshots/lays_onduladas.png', TRUE),
        ('7758574005626', 'Chizitos Queso Personal 44g', 'Frito-Lay', 'Snacks y Piqueos', 1.50, 1.10, 'packshots/chizitos_queso.png', TRUE),
        ('7750670010856', 'Cuates Picantes Personal 43g', 'Karinto', 'Snacks y Piqueos', 1.00, 0.75, 'packshots/cuates_picantes_100g.png', TRUE),
        ('7750670010863', 'Maní Salado Karinto Personal 45g', 'Karinto', 'Snacks y Piqueos', 1.00, 0.75, 'packshots/mani_karinto.png', TRUE),
        ('7750670010924', 'Papas Artesanales Inka Chips Sal Marina Personal 42g', 'Inka Chips', 'Snacks y Piqueos', 2.50, 1.90, 'packshots/inka_chips_sal_marina.png', TRUE),
        -- Lácteos y Derivados (latas chicas, lonchera, barra económica y plancha huevos x30)
        ('7750108003358', 'Leche Gloria Roja Entera Chica 170g', 'Gloria', 'Lácteos y Derivados', 2.40, 1.95, 'packshots/leche_gloria_roja.png', TRUE),
        ('7750108003365', 'Leche Gloria Light Chica 170g', 'Gloria', 'Lácteos y Derivados', 2.40, 1.95, 'packshots/leche_gloria_light.png', TRUE),
        ('7750108003372', 'Leche Chocolatada Gloria Cajita Personal 200ml', 'Gloria', 'Lácteos y Derivados', 1.80, 1.35, 'packshots/leche_chocolatada_gloria.png', TRUE),
        ('7750108003389', 'Margarina Manty Barra 90g', 'Manty', 'Lácteos y Derivados', 1.80, 1.35, 'packshots/margarina_manty.png', TRUE),
        ('7750108003396', 'Huevos Pardos La Calera Bandeja x30 unidades', 'La Calera', 'Lácteos y Derivados', 18.00, 15.00, 'packshots/huevos_la_calera_x15.png', TRUE),
        -- Abarrotes y Despensa (formatos 500ml, 5kg familiar, sachets 100g y sabores)
        ('7750109004423', 'Aceite Vegetal Primor Clásico Botella 500ml', 'Primor', 'Abarrotes y Despensa', 5.00, 4.10, 'packshots/aceite_primor.png', TRUE),
        ('7750109004430', 'Aceite Vegetal Cocinero Botella 500ml', 'Cocinero', 'Abarrotes y Despensa', 4.50, 3.70, 'packshots/aceite_cocinero.png', TRUE),
        ('7750109004447', 'Azúcar Rubia Paramonga Bolsa 5kg Familiar', 'Paramonga', 'Abarrotes y Despensa', 19.00, 16.00, 'packshots/azucar_paramonga.png', TRUE),
        ('7750109004454', 'Sopa Instantánea Ajinomen Carne 80g', 'Ajinomoto', 'Abarrotes y Despensa', 2.00, 1.50, 'packshots/ajinomen_pollo.png', TRUE),
        ('7750243030427', 'Ketchup AlaCena Sachet 100g', 'AlaCena', 'Abarrotes y Despensa', 2.00, 1.50, 'packshots/ketchup_alacena_380g.png', TRUE),
        ('7750109004461', 'Sillao Kikko Clásico Botella 160ml', 'Kikko', 'Abarrotes y Despensa', 2.00, 1.50, 'packshots/sillao_kikko_500ml.png', TRUE),
        -- Golosinas, Panadería y Desayuno (doypacks, sachets y sabores populares)
        ('7613036615549', 'Bebida Achocolatada Milo Nestlé Doypack 180g', 'Nestlé', 'Panadería y Desayuno', 8.50, 6.80, 'packshots/milo_nestle_400g.png', TRUE),
        ('7613036615556', 'Chocolate Sublime Blanco 30g', 'Nestlé', 'Golosinas y Chocolates', 2.00, 1.50, 'packshots/chocolate_sublime.png', TRUE),
        ('7750115010356', 'Galleta Casino Lúcuma 68g', 'Victoria', 'Golosinas y Chocolates', 1.00, 0.75, 'packshots/galleta_casino.png', TRUE),
        ('7750115010363', 'Galleta Tentación Naranja 70g', 'Victoria', 'Golosinas y Chocolates', 1.00, 0.75, 'packshots/galleta_tentacion.png', TRUE),
        ('7750116011124', 'Mermelada de Fresa Gloria Sachet 100g', 'Gloria', 'Panadería y Desayuno', 1.80, 1.35, 'packshots/mermelada_gloria.png', TRUE),
        -- Limpieza, Cuidado Personal y Embutidos (formatos económicos y prácticos)
        ('7750114009336', 'Detergente Opal Ultra Bolsa 330g', 'Opal', 'Limpieza y Cuidado del Hogar', 3.80, 3.00, 'packshots/detergente_opal.png', TRUE),
        ('7750114009343', 'Suavizante Suavitel Fresca Primavera Sachet 200ml', 'Suavitel', 'Limpieza y Cuidado del Hogar', 2.00, 1.50, 'packshots/suavizante_suavitel.png', TRUE),
        ('7750114009350', 'Limpiador Multiusos Poett Lavanda Botella 450ml', 'Poett', 'Limpieza y Cuidado del Hogar', 2.80, 2.15, 'packshots/limpiador_poett.png', TRUE),
        ('7750113008209', 'Papel Higiénico Elite Dúo Doble Hoja x2 rollos', 'Elite', 'Cuidado Personal y Dental', 3.20, 2.50, 'packshots/papel_higienico_elite.png', TRUE),
        ('7750107002122', 'Queso Fresco Bonlé Gloria Tajado 200g', 'Gloria', 'Embutidos y Fiambrería', 5.20, 4.10, 'packshots/queso_fresco_bonle.png', TRUE)
    ON CONFLICT (codigo_barras) DO UPDATE SET
        imagen_url = EXCLUDED.imagen_url,
        activo = TRUE;

    -- 2. Sembrar las 40 variantes en Bodega KARLIZ con stock comercial inicial visible
    SELECT id_bodega INTO v_bodega_id
    FROM bodegas
    WHERE id_bodega = 1 OR nombre_comercial ILIKE '%KARLIZ%'
    ORDER BY id_bodega ASC
    LIMIT 1;

    IF v_bodega_id IS NOT NULL THEN
        FOR v_item IN
            SELECT * FROM (VALUES
                ('7750106001126', 'Inca Kola Sin Azúcar Zero 1.5 Litros', 'Inca Kola', 'Gaseosas y Bebidas', 6.50, 5.20, 'packshots/inka_kola.png', 18.000),
                ('7750106001133', 'Inca Kola Sin Azúcar Zero 3 Litros', 'Inca Kola', 'Gaseosas y Bebidas', 12.00, 9.80, 'packshots/inka_kola_3l.png', 12.000),
                ('7750106002123', 'Coca Cola Sin Azúcar Zero 1.5 Litros', 'Coca Cola', 'Gaseosas y Bebidas', 6.50, 5.20, 'packshots/coca_cola.png', 18.000),
                ('7750106002130', 'Coca Cola Sin Azúcar Zero 3 Litros', 'Coca Cola', 'Gaseosas y Bebidas', 12.00, 9.80, 'packshots/coca_cola_3l.png', 12.000),
                ('7750106003038', 'Agua San Luis Sin Gas 2.5 Litros', 'San Luis', 'Gaseosas y Bebidas', 3.50, 2.70, 'packshots/agua_san_luis.png', 20.000),
                ('7750670010047', 'Agua Cielo Sin Gas 2.5 Litros', 'Cielo', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/agua_cielo.png', 20.000),
                ('7750106008057', 'Jugo Frugos del Valle Durazno Botella 300ml', 'Frugos', 'Gaseosas y Bebidas', 1.80, 1.35, 'packshots/frugos_durazno.png', 24.000),
                ('7750106008064', 'Jugo Frugos del Valle Mango Botella 300ml', 'Frugos', 'Gaseosas y Bebidas', 1.80, 1.35, 'packshots/frugos_mango.png', 24.000),
                ('7750106006046', 'Cerveza Cusqueña Trigo 620ml Retornable', 'Cusqueña', 'Bebidas Alcohólicas', 7.50, 6.00, 'packshots/cerveza_cusquena.png', 24.000),
                ('7750106006053', 'Cerveza Cusqueña Dorada Six-Pack Botella 310ml', 'Cusqueña', 'Bebidas Alcohólicas', 30.00, 24.50, 'packshots/cerveza_cusquena_dorada.png', 10.000),
                ('7750111006625', 'Cerveza Pilsen Callao Botella Personal 305ml', 'Pilsen Callao', 'Bebidas Alcohólicas', 4.00, 3.15, 'packshots/cerveza_pilsen.png', 24.000),
                ('7891991000833', 'Cerveza Stella Artois Six-Pack Botella 330ml', 'Stella Artois', 'Bebidas Alcohólicas', 36.00, 29.00, 'packshots/cerveza_stella.png', 10.000),
                ('7750170000029', 'Vino Tabernero Rose Semi Seco 750ml', 'Tabernero', 'Bebidas Alcohólicas', 21.00, 16.80, 'packshots/vino_tabernero.png', 12.000),
                ('7758574005602', 'Papas Fritas Lay''s Clásicas Personal 42g', 'Lay''s', 'Snacks y Piqueos', 2.00, 1.50, 'packshots/lays_clasicas_140g.png', 36.000),
                ('7758574005619', 'Papas Fritas Lay''s Ondas Personal 42g', 'Lay''s', 'Snacks y Piqueos', 2.00, 1.50, 'packshots/lays_onduladas.png', 36.000),
                ('7758574005626', 'Chizitos Queso Personal 44g', 'Frito-Lay', 'Snacks y Piqueos', 1.50, 1.10, 'packshots/chizitos_queso.png', 40.000),
                ('7750670010856', 'Cuates Picantes Personal 43g', 'Karinto', 'Snacks y Piqueos', 1.00, 0.75, 'packshots/cuates_picantes_100g.png', 48.000),
                ('7750670010863', 'Maní Salado Karinto Personal 45g', 'Karinto', 'Snacks y Piqueos', 1.00, 0.75, 'packshots/mani_karinto.png', 48.000),
                ('7750670010924', 'Papas Artesanales Inka Chips Sal Marina Personal 42g', 'Inka Chips', 'Snacks y Piqueos', 2.50, 1.90, 'packshots/inka_chips_sal_marina.png', 30.000),
                ('7750108003358', 'Leche Gloria Roja Entera Chica 170g', 'Gloria', 'Lácteos y Derivados', 2.40, 1.95, 'packshots/leche_gloria_roja.png', 36.000),
                ('7750108003365', 'Leche Gloria Light Chica 170g', 'Gloria', 'Lácteos y Derivados', 2.40, 1.95, 'packshots/leche_gloria_light.png', 30.000),
                ('7750108003372', 'Leche Chocolatada Gloria Cajita Personal 200ml', 'Gloria', 'Lácteos y Derivados', 1.80, 1.35, 'packshots/leche_chocolatada_gloria.png', 36.000),
                ('7750108003389', 'Margarina Manty Barra 90g', 'Manty', 'Lácteos y Derivados', 1.80, 1.35, 'packshots/margarina_manty.png', 30.000),
                ('7750108003396', 'Huevos Pardos La Calera Bandeja x30 unidades', 'La Calera', 'Lácteos y Derivados', 18.00, 15.00, 'packshots/huevos_la_calera_x15.png', 12.000),
                ('7750109004423', 'Aceite Vegetal Primor Clásico Botella 500ml', 'Primor', 'Abarrotes y Despensa', 5.00, 4.10, 'packshots/aceite_primor.png', 20.000),
                ('7750109004430', 'Aceite Vegetal Cocinero Botella 500ml', 'Cocinero', 'Abarrotes y Despensa', 4.50, 3.70, 'packshots/aceite_cocinero.png', 20.000),
                ('7750109004447', 'Azúcar Rubia Paramonga Bolsa 5kg Familiar', 'Paramonga', 'Abarrotes y Despensa', 19.00, 16.00, 'packshots/azucar_paramonga.png', 10.000),
                ('7750109004454', 'Sopa Instantánea Ajinomen Carne 80g', 'Ajinomoto', 'Abarrotes y Despensa', 2.00, 1.50, 'packshots/ajinomen_pollo.png', 36.000),
                ('7750243030427', 'Ketchup AlaCena Sachet 100g', 'AlaCena', 'Abarrotes y Despensa', 2.00, 1.50, 'packshots/ketchup_alacena_380g.png', 30.000),
                ('7750109004461', 'Sillao Kikko Clásico Botella 160ml', 'Kikko', 'Abarrotes y Despensa', 2.00, 1.50, 'packshots/sillao_kikko_500ml.png', 24.000),
                ('7613036615549', 'Bebida Achocolatada Milo Nestlé Doypack 180g', 'Nestlé', 'Panadería y Desayuno', 8.50, 6.80, 'packshots/milo_nestle_400g.png', 20.000),
                ('7613036615556', 'Chocolate Sublime Blanco 30g', 'Nestlé', 'Golosinas y Chocolates', 2.00, 1.50, 'packshots/chocolate_sublime.png', 36.000),
                ('7750115010356', 'Galleta Casino Lúcuma 68g', 'Victoria', 'Golosinas y Chocolates', 1.00, 0.75, 'packshots/galleta_casino.png', 40.000),
                ('7750115010363', 'Galleta Tentación Naranja 70g', 'Victoria', 'Golosinas y Chocolates', 1.00, 0.75, 'packshots/galleta_tentacion.png', 40.000),
                ('7750116011124', 'Mermelada de Fresa Gloria Sachet 100g', 'Gloria', 'Panadería y Desayuno', 1.80, 1.35, 'packshots/mermelada_gloria.png', 30.000),
                ('7750114009336', 'Detergente Opal Ultra Bolsa 330g', 'Opal', 'Limpieza y Cuidado del Hogar', 3.80, 3.00, 'packshots/detergente_opal.png', 24.000),
                ('7750114009343', 'Suavizante Suavitel Fresca Primavera Sachet 200ml', 'Suavitel', 'Limpieza y Cuidado del Hogar', 2.00, 1.50, 'packshots/suavizante_suavitel.png', 30.000),
                ('7750114009350', 'Limpiador Multiusos Poett Lavanda Botella 450ml', 'Poett', 'Limpieza y Cuidado del Hogar', 2.80, 2.15, 'packshots/limpiador_poett.png', 24.000),
                ('7750113008209', 'Papel Higiénico Elite Dúo Doble Hoja x2 rollos', 'Elite', 'Cuidado Personal y Dental', 3.20, 2.50, 'packshots/papel_higienico_elite.png', 24.000),
                ('7750107002122', 'Queso Fresco Bonlé Gloria Tajado 200g', 'Gloria', 'Embutidos y Fiambrería', 5.20, 4.10, 'packshots/queso_fresco_bonle.png', 18.000)
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
