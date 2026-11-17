-- ==============================================================================
-- Migración v33: Expansión de 15 productos comerciales peruanos de alta rotación
-- con precios reales de bodega y fotografías profesionales de estudio (packshots).
-- 100% idempotente: sincroniza el preset global y enriquece Bodega KARLIZ (ID 1).
-- ==============================================================================

DO $$
DECLARE
    v_bodega_id BIGINT;
    v_cat_id BIGINT;
    v_item RECORD;
BEGIN
    -- 1. Asegurar los 15 nuevos productos comerciales en el Preset Global del SuperAdmin
    INSERT INTO catalogo_starter_pack_global (
        codigo_barras, nombre, marca, categoria, precio_venta, precio_costo, imagen_url, activo
    ) VALUES
        ('7613036615501', 'Bebida Achocolatada Milo Nestlé Lata 400g', 'Nestlé', 'Panadería y Desayuno', 16.50, 13.40, 'packshots/milo_nestle_400g.png', TRUE),
        ('7613036615518', 'Chocolate Princesa D''Onofrio Clásico 30g', 'D''Onofrio', 'Golosinas y Chocolates', 2.00, 1.50, 'packshots/chocolate_princesa.png', TRUE),
        ('7750115010202', 'Galleta Pícaras Bañadas en Chocolate 40g', 'Costa', 'Golosinas y Chocolates', 1.20, 0.85, 'packshots/galleta_picaras.png', TRUE),
        ('7750109004300', 'Sopa Instantánea Ajinomen Pollo 80g', 'Ajinomoto', 'Abarrotes y Despensa', 2.00, 1.50, 'packshots/ajinomen_pollo.png', TRUE),
        ('7750243030410', 'Ketchup AlaCena Doypack 380g', 'AlaCena', 'Abarrotes y Despensa', 5.50, 4.30, 'packshots/ketchup_alacena_380g.png', TRUE),
        ('7750109004317', 'Sillao Kikko Clásico Botella 500ml', 'Kikko', 'Abarrotes y Despensa', 4.20, 3.30, 'packshots/sillao_kikko_500ml.png', TRUE),
        ('7750109004324', 'Filete de Atún Campomar en Aceite Vegetal 170g', 'Campomar', 'Abarrotes y Despensa', 5.80, 4.60, 'packshots/atun_campomar_170g.png', TRUE),
        ('7750108003204', 'Huevos Pardos La Calera Bandeja x15 unidades', 'La Calera', 'Lácteos y Derivados', 9.50, 7.80, 'packshots/huevos_la_calera_x15.png', TRUE),
        ('7613036615525', 'Leche Evaporada Ideal Cremosa Nestlé 395g', 'Nestlé', 'Lácteos y Derivados', 4.00, 3.40, 'packshots/leche_ideal_cremosa.png', TRUE),
        ('7750670010917', 'Papas Artesanales Inka Chips Sal Marina 135g', 'Inka Chips', 'Snacks y Piqueos', 6.50, 5.10, 'packshots/inka_chips_sal_marina.png', TRUE),
        ('7758574005596', 'Cheese Tris Personal 44g', 'Frito-Lay', 'Snacks y Piqueos', 1.50, 1.10, 'packshots/cheese_tris_44g.png', TRUE),
        ('7750182000710', 'Bebida Rehidratante Powerade Mountain Blast 500ml', 'Powerade', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/powerade_mountain_blast.png', TRUE),
        ('7750114009206', 'Suavizante Downy Amanecer Botella 750ml', 'Downy', 'Limpieza y Cuidado del Hogar', 9.50, 7.60, 'packshots/suavizante_downy_750ml.png', TRUE),
        ('7750114009213', 'Jabón de Lavar Ropa Bolívar Clásico Azul 190g', 'Bolívar', 'Limpieza y Cuidado del Hogar', 3.50, 2.75, 'packshots/jabon_bolivar_azul.png', TRUE),
        ('7750110005185', 'Helado Frío Rico D''Onofrio Multipack x4', 'D''Onofrio', 'Helados y Congelados', 14.50, 11.50, 'packshots/helado_frio_rico_multipack.png', TRUE)
    ON CONFLICT (codigo_barras) DO UPDATE SET
        imagen_url = EXCLUDED.imagen_url,
        activo = TRUE;

    -- 2. Corregir imágenes mal asignadas en productos de limpieza existentes
    UPDATE productos
    SET imagen_url = 'packshots/lavavajilla_ayudin.png'
    WHERE nombre ILIKE '%Ayudín%' AND imagen_url = 'packshots/crema_tari.png';

    UPDATE productos
    SET imagen_url = 'packshots/lavavajilla_sapolio.png'
    WHERE nombre ILIKE '%Sapolio%' AND imagen_url = 'packshots/crema_tari.png';

    -- 3. Sembrar los 15 productos en Bodega KARLIZ (bodega principal) con stock comercial inicial visible
    SELECT id_bodega INTO v_bodega_id
    FROM bodegas
    WHERE id_bodega = 1 OR nombre_comercial ILIKE '%KARLIZ%'
    ORDER BY id_bodega ASC
    LIMIT 1;

    IF v_bodega_id IS NOT NULL THEN
        FOR v_item IN
            SELECT * FROM (VALUES
                ('7613036615501', 'Bebida Achocolatada Milo Nestlé Lata 400g', 'Nestlé', 'Panadería y Desayuno', 16.50, 13.40, 'packshots/milo_nestle_400g.png', 18.000),
                ('7613036615518', 'Chocolate Princesa D''Onofrio Clásico 30g', 'D''Onofrio', 'Golosinas y Chocolates', 2.00, 1.50, 'packshots/chocolate_princesa.png', 36.000),
                ('7750115010202', 'Galleta Pícaras Bañadas en Chocolate 40g', 'Costa', 'Golosinas y Chocolates', 1.20, 0.85, 'packshots/galleta_picaras.png', 40.000),
                ('7750109004300', 'Sopa Instantánea Ajinomen Pollo 80g', 'Ajinomoto', 'Abarrotes y Despensa', 2.00, 1.50, 'packshots/ajinomen_pollo.png', 36.000),
                ('7750243030410', 'Ketchup AlaCena Doypack 380g', 'AlaCena', 'Abarrotes y Despensa', 5.50, 4.30, 'packshots/ketchup_alacena_380g.png', 20.000),
                ('7750109004317', 'Sillao Kikko Clásico Botella 500ml', 'Kikko', 'Abarrotes y Despensa', 4.20, 3.30, 'packshots/sillao_kikko_500ml.png', 18.000),
                ('7750109004324', 'Filete de Atún Campomar en Aceite Vegetal 170g', 'Campomar', 'Abarrotes y Despensa', 5.80, 4.60, 'packshots/atun_campomar_170g.png', 24.000),
                ('7750108003204', 'Huevos Pardos La Calera Bandeja x15 unidades', 'La Calera', 'Lácteos y Derivados', 9.50, 7.80, 'packshots/huevos_la_calera_x15.png', 15.000),
                ('7613036615525', 'Leche Evaporada Ideal Cremosa Nestlé 395g', 'Nestlé', 'Lácteos y Derivados', 4.00, 3.40, 'packshots/leche_ideal_cremosa.png', 36.000),
                ('7750670010917', 'Papas Artesanales Inka Chips Sal Marina 135g', 'Inka Chips', 'Snacks y Piqueos', 6.50, 5.10, 'packshots/inka_chips_sal_marina.png', 20.000),
                ('7758574005596', 'Cheese Tris Personal 44g', 'Frito-Lay', 'Snacks y Piqueos', 1.50, 1.10, 'packshots/cheese_tris_44g.png', 30.000),
                ('7750182000710', 'Bebida Rehidratante Powerade Mountain Blast 500ml', 'Powerade', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/powerade_mountain_blast.png', 24.000),
                ('7750114009206', 'Suavizante Downy Amanecer Botella 750ml', 'Downy', 'Limpieza y Cuidado del Hogar', 9.50, 7.60, 'packshots/suavizante_downy_750ml.png', 14.000),
                ('7750114009213', 'Jabón de Lavar Ropa Bolívar Clásico Azul 190g', 'Bolívar', 'Limpieza y Cuidado del Hogar', 3.50, 2.75, 'packshots/jabon_bolivar_azul.png', 24.000),
                ('7750110005185', 'Helado Frío Rico D''Onofrio Multipack x4', 'D''Onofrio', 'Helados y Congelados', 14.50, 11.50, 'packshots/helado_frio_rico_multipack.png', 12.000)
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
