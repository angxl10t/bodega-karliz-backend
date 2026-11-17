-- ==============================================================================
-- Migración v34: Auditoría de calidad (imágenes y precios reales) + 32 nuevas
-- variantes comerciales de tamaño, sabor y presentación (personal, 1L, 1.5L,
-- 5kg, latas, six-packs y sabores) para bodegas peruanas.
-- 100% idempotente.
-- ==============================================================================

DO $$
DECLARE
    v_bodega_id BIGINT;
    v_cat_id BIGINT;
    v_item RECORD;
BEGIN
    -- ==========================================================================
    -- 1. REPARACIÓN DE IMÁGENES EQUIVOCADAS / EXTERNAS EN PRODUCTOS EXISTENTES
    -- ==========================================================================
    UPDATE productos SET imagen_url = 'packshots/atun_primor.png'
    WHERE nombre ILIKE '%Atún Primor%' AND imagen_url = 'packshots/aceite_primor.png';

    UPDATE productos SET imagen_url = 'packshots/ketchup_alacena_380g.png'
    WHERE (nombre ILIKE '%Kétchup AlaCena%' OR nombre ILIKE '%Ketchup AlaCena%')
      AND imagen_url <> 'packshots/ketchup_alacena_380g.png';

    UPDATE productos SET imagen_url = 'packshots/cigarros_hamilton.png'
    WHERE nombre ILIKE '%Hamilton%' AND (imagen_url IS NULL OR imagen_url = '' OR imagen_url = 'packshots/helado_jet.png');

    UPDATE productos SET nombre = 'Marlboro Gold Box Cajetilla x20', imagen_url = 'packshots/cigarros_malboro.png'
    WHERE nombre ILIKE 'Malboro Gold%' AND (imagen_url IS NULL OR imagen_url = '' OR imagen_url = 'packshots/helado_jet.png');

    UPDATE productos SET imagen_url = 'packshots/cigarros_pall_mall.png'
    WHERE nombre ILIKE '%Pall Mall%' AND (imagen_url IS NULL OR imagen_url = '' OR imagen_url = 'packshots/helado_jet.png');

    UPDATE productos SET imagen_url = 'packshots/cigarros_lucky_strike.png'
    WHERE nombre ILIKE '%Lucky Strike%' AND (imagen_url IS NULL OR imagen_url = '' OR imagen_url = 'packshots/helado_jet.png');

    UPDATE productos SET imagen_url = 'packshots/fosforos_la_llama.png'
    WHERE nombre ILIKE '%Fósforos La Llama%' AND imagen_url = 'packshots/crema_tari.png';

    UPDATE productos SET imagen_url = 'packshots/coca_cola.png'
    WHERE nombre ILIKE 'Coca Cola 1.5L%' AND imagen_url ILIKE 'http%';

    UPDATE productos SET imagen_url = 'packshots/coca_cola_3l.png'
    WHERE nombre ILIKE '%Coca Cola%3 L%' AND imagen_url = 'packshots/coca_cola.png';

    UPDATE productos SET imagen_url = 'packshots/inka_kola.png'
    WHERE nombre ILIKE 'Inca Kola 1.5L%' AND imagen_url = 'packshots/inka_kola_3l.png';

    UPDATE productos SET imagen_url = 'packshots/inka_kola_500ml.png'
    WHERE nombre ILIKE '%Inca Kola%500ml%' AND imagen_url = 'packshots/inka_kola.png';

    UPDATE productos SET imagen_url = 'packshots/fanta_500ml.png'
    WHERE nombre ILIKE '%Fanta%500ml%' AND imagen_url = 'packshots/fanta.png';

    -- ==========================================================================
    -- 2. NORMALIZACIÓN DE PRECIOS IRREALES / INVERTIDOS EN BODEGA KARLIZ (ID 1)
    -- ==========================================================================
    SELECT id_bodega INTO v_bodega_id
    FROM bodegas
    WHERE id_bodega = 1 OR nombre_comercial ILIKE '%KARLIZ%'
    ORDER BY id_bodega ASC
    LIMIT 1;

    IF v_bodega_id IS NOT NULL THEN
        UPDATE productos SET precio_venta = 6.90, precio_costo = 5.50
        WHERE id_bodega = v_bodega_id AND codigo = 'ABA-0013' AND precio_venta < 3.00;

        UPDATE productos SET precio_venta = 5.50, precio_costo = 4.30
        WHERE id_bodega = v_bodega_id AND codigo = 'ABA-0011' AND precio_venta > 8.00;

        UPDATE productos SET precio_venta = 4.00, precio_costo = 3.30
        WHERE id_bodega = v_bodega_id AND codigo = 'ABA-0008' AND precio_venta > 6.00;

        UPDATE productos SET precio_venta = 7.80, precio_costo = 6.50
        WHERE id_bodega = v_bodega_id AND codigo = 'ABA-0007' AND precio_venta < 6.00;

        UPDATE productos SET precio_venta = 3.00, precio_costo = 2.30
        WHERE id_bodega = v_bodega_id AND codigo = 'GSE-0005' AND precio_venta > 5.00;

        UPDATE productos SET precio_venta = 6.50, precio_costo = 5.20
        WHERE id_bodega = v_bodega_id AND codigo = 'GSE-0006' AND precio_venta > 7.00;

        UPDATE productos SET precio_venta = 3.00, precio_costo = 2.30
        WHERE id_bodega = v_bodega_id AND codigo = 'GSE-0002' AND precio_venta > 3.50;

        UPDATE productos SET precio_venta = 2.50, precio_costo = 1.90
        WHERE id_bodega = v_bodega_id AND codigo = 'GSE-0011' AND precio_venta > 3.50;

        UPDATE productos SET precio_venta = 12.50, precio_costo = 9.80
        WHERE id_bodega = v_bodega_id AND codigo = 'HLD-0004' AND precio_venta < 8.00;

        UPDATE productos SET precio_venta = 2.00, precio_costo = 1.50
        WHERE id_bodega = v_bodega_id AND codigo = 'SNK-0008' AND precio_venta > 3.00;

        UPDATE productos SET precio_venta = 3.80, precio_costo = 2.90
        WHERE id_bodega = v_bodega_id AND codigo = 'PROD-7750670010825' AND precio_venta < 3.50;

        UPDATE productos SET precio_venta = 18.00, precio_costo = 15.00
        WHERE id_bodega = v_bodega_id AND codigo = 'CIG-0001' AND precio_venta < 14.00;
    END IF;

    -- ==========================================================================
    -- 3. 32 NUEVAS VARIANTES DE TAMAÑO, SABOR Y PRESENTACIÓN EN PRESET GLOBAL
    -- ==========================================================================
    INSERT INTO catalogo_starter_pack_global (
        codigo_barras, nombre, marca, categoria, precio_venta, precio_costo, imagen_url, activo
    ) VALUES
        -- Gaseosas y Bebidas (tamaños y sabores faltantes)
        ('7750106001102', 'Inca Kola Sabor Original 1 Litro', 'Inca Kola', 'Gaseosas y Bebidas', 4.50, 3.60, 'packshots/inka_kola.png', TRUE),
        ('7750106001119', 'Inca Kola Sabor Original Lata 355ml', 'Inca Kola', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/inka_kola_500ml.png', TRUE),
        ('7750106002109', 'Coca Cola Sabor Original 1 Litro', 'Coca Cola', 'Gaseosas y Bebidas', 4.50, 3.60, 'packshots/coca_cola.png', TRUE),
        ('7750106002116', 'Coca Cola Sabor Original Lata 355ml', 'Coca Cola', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/coca_cola_500ml.png', TRUE),
        ('7750182220385', 'Gaseosa Fanta Naranja 1.5 Litros', 'Fanta', 'Gaseosas y Bebidas', 5.80, 4.60, 'packshots/fanta.png', TRUE),
        ('7750182000338', 'Gaseosa Sprite Lima Limón 1.5 Litros', 'Sprite', 'Gaseosas y Bebidas', 5.80, 4.60, 'packshots/sprite.png', TRUE),
        ('7750106008019', 'Jugo Frugos del Valle Durazno 1 Litro', 'Frugos', 'Gaseosas y Bebidas', 3.80, 2.90, 'packshots/frugos_durazno.png', TRUE),
        ('775117011960',  'Agua Mineral San Mateo Con Gas 600ml', 'San Mateo', 'Gaseosas y Bebidas', 1.60, 1.15, 'packshots/agua_san_mateo_600ml.png', TRUE),
        -- Bebidas Alcohólicas (latas, retornables y six-packs)
        ('7750111006045', 'Cerveza Cristal Lata 355ml', 'Cristal', 'Bebidas Alcohólicas', 4.20, 3.30, 'packshots/cerveza_cristal_lata.png', TRUE),
        ('7750111006601', 'Cerveza Pilsen Callao Six-Pack Latas 355ml', 'Pilsen Callao', 'Bebidas Alcohólicas', 23.50, 19.20, 'packshots/cerveza_pilsen.png', TRUE),
        ('7750111006618', 'Cerveza Cristal Six-Pack Latas 355ml', 'Cristal', 'Bebidas Alcohólicas', 22.50, 18.50, 'packshots/cerveza_cristal_lata.png', TRUE),
        ('7750106006039', 'Cerveza Cusqueña Dorada 620ml Retornable', 'Cusqueña', 'Bebidas Alcohólicas', 7.50, 6.00, 'packshots/cerveza_cusquena_dorada.png', TRUE),
        ('750106419173',  'Cerveza Corona Extra Six-Pack Botella 355ml', 'Corona', 'Bebidas Alcohólicas', 34.00, 27.50, 'packshots/cerveza_corona.png', TRUE),
        -- Lácteos y Derivados (tamaños personales, six-pack y sabores)
        ('7750108003303', 'Leche Gloria Azul Evaporada Chica 170g', 'Gloria', 'Lácteos y Derivados', 2.40, 1.95, 'packshots/leche_gloria_azul.png', TRUE),
        ('7750108003310', 'Leche Gloria Azul Evaporada Six-Pack x6 Latas 400g', 'Gloria', 'Lácteos y Derivados', 24.00, 21.00, 'packshots/leche_gloria_azul.png', TRUE),
        ('7750108003327', 'Yogur Gloria Fresa Botella Personal 185g', 'Gloria', 'Lácteos y Derivados', 2.20, 1.70, 'packshots/yogur_gloria_fresa.png', TRUE),
        ('7750108003334', 'Yogur Gloria Vainilla Botella Personal 185g', 'Gloria', 'Lácteos y Derivados', 2.20, 1.70, 'packshots/yogur_gloria_vainilla.png', TRUE),
        ('7750108003341', 'Yogur Gloria Durazno Botella 1 Litro', 'Gloria', 'Lácteos y Derivados', 6.20, 5.00, 'packshots/yogur_gloria_vainilla_1kg.png', TRUE),
        -- Golosinas y Chocolates (sabores y presentaciones personales)
        ('7750115010301', 'Galleta Casino Menta 68g', 'Victoria', 'Golosinas y Chocolates', 1.00, 0.75, 'packshots/galleta_casino.png', TRUE),
        ('7750115010318', 'Galleta Casino Chocolate 68g', 'Victoria', 'Golosinas y Chocolates', 1.00, 0.75, 'packshots/galleta_casino.png', TRUE),
        ('7750115010325', 'Galleta Tentación Vainilla 70g', 'Victoria', 'Golosinas y Chocolates', 1.00, 0.75, 'packshots/galleta_tentacion.png', TRUE),
        ('7750115010332', 'Galleta Oreo Original Paquete x4 (36g)', 'Oreo', 'Golosinas y Chocolates', 1.20, 0.90, 'packshots/galleta_oreo.png', TRUE),
        ('7750115010349', 'Pastillas Halls Menta Eucalipto', 'Halls', 'Golosinas y Chocolates', 1.00, 0.70, 'packshots/halls_menta.png', TRUE),
        -- Abarrotes, Desayuno, Limpieza y Embutidos (tamaños familiar y económico)
        ('7750109004409', 'Arroz Extra Costeño Bolsa 5kg Familiar', 'Costeño', 'Abarrotes y Despensa', 21.50, 18.20, 'packshots/arroz_costeno.png', TRUE),
        ('7750109004416', 'Arroz Superior Faraón Bolsa 5kg Familiar', 'Faraón', 'Abarrotes y Despensa', 20.50, 17.50, 'packshots/arroz_faraon.png', TRUE),
        ('7750116011100', 'Avena Precocida 3 Ositos Bolsa Familiar 500g', '3 Ositos', 'Panadería y Desayuno', 3.80, 2.95, 'packshots/avena_tres_ositos.png', TRUE),
        ('7750116011117', 'Café Soluble Nescafé Tradición Doypack 50g', 'Nescafé', 'Panadería y Desayuno', 6.20, 4.90, 'packshots/cafe_nescafe.png', TRUE),
        ('7750114009305', 'Detergente Bolívar Blanco Activo Bolsa 450g', 'Bolívar', 'Limpieza y Cuidado del Hogar', 4.80, 3.80, 'packshots/detergente_bolivar.png', TRUE),
        ('7750114009312', 'Detergente Ace Limpieza Completa Bolsa 330g', 'Ace', 'Limpieza y Cuidado del Hogar', 3.80, 3.00, 'packshots/detergente_ace.png', TRUE),
        ('7750114009329', 'Lejía Clorox Tradicional Botella 680ml', 'Clorox', 'Limpieza y Cuidado del Hogar', 2.20, 1.70, 'packshots/lejia_clorox.png', TRUE),
        ('7750107002108', 'Hot Dog de Pollo San Fernando Económico 250g', 'San Fernando', 'Embutidos y Fiambrería', 3.20, 2.50, 'packshots/hot_dog_pollo.png', TRUE),
        ('7750107002115', 'Jamonada de Pollo San Fernando Económica 200g', 'San Fernando', 'Embutidos y Fiambrería', 3.50, 2.75, 'packshots/jamonada_pollo.png', TRUE)
    ON CONFLICT (codigo_barras) DO UPDATE SET
        imagen_url = EXCLUDED.imagen_url,
        activo = TRUE;

    -- ==========================================================================
    -- 4. SEMBRAR LAS 32 VARIANTES EN BODEGA KARLIZ CON STOCK INICIAL COMERCIAL
    -- ==========================================================================
    IF v_bodega_id IS NOT NULL THEN
        FOR v_item IN
            SELECT * FROM (VALUES
                ('7750106001102', 'Inca Kola Sabor Original 1 Litro', 'Inca Kola', 'Gaseosas y Bebidas', 4.50, 3.60, 'packshots/inka_kola.png', 24.000),
                ('7750106001119', 'Inca Kola Sabor Original Lata 355ml', 'Inca Kola', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/inka_kola_500ml.png', 36.000),
                ('7750106002109', 'Coca Cola Sabor Original 1 Litro', 'Coca Cola', 'Gaseosas y Bebidas', 4.50, 3.60, 'packshots/coca_cola.png', 24.000),
                ('7750106002116', 'Coca Cola Sabor Original Lata 355ml', 'Coca Cola', 'Gaseosas y Bebidas', 2.80, 2.15, 'packshots/coca_cola_500ml.png', 36.000),
                ('7750182220385', 'Gaseosa Fanta Naranja 1.5 Litros', 'Fanta', 'Gaseosas y Bebidas', 5.80, 4.60, 'packshots/fanta.png', 18.000),
                ('7750182000338', 'Gaseosa Sprite Lima Limón 1.5 Litros', 'Sprite', 'Gaseosas y Bebidas', 5.80, 4.60, 'packshots/sprite.png', 18.000),
                ('7750106008019', 'Jugo Frugos del Valle Durazno 1 Litro', 'Frugos', 'Gaseosas y Bebidas', 3.80, 2.90, 'packshots/frugos_durazno.png', 20.000),
                ('775117011960',  'Agua Mineral San Mateo Con Gas 600ml', 'San Mateo', 'Gaseosas y Bebidas', 1.60, 1.15, 'packshots/agua_san_mateo_600ml.png', 30.000),
                ('7750111006045', 'Cerveza Cristal Lata 355ml', 'Cristal', 'Bebidas Alcohólicas', 4.20, 3.30, 'packshots/cerveza_cristal_lata.png', 36.000),
                ('7750111006601', 'Cerveza Pilsen Callao Six-Pack Latas 355ml', 'Pilsen Callao', 'Bebidas Alcohólicas', 23.50, 19.20, 'packshots/cerveza_pilsen.png', 12.000),
                ('7750111006618', 'Cerveza Cristal Six-Pack Latas 355ml', 'Cristal', 'Bebidas Alcohólicas', 22.50, 18.50, 'packshots/cerveza_cristal_lata.png', 12.000),
                ('7750106006039', 'Cerveza Cusqueña Dorada 620ml Retornable', 'Cusqueña', 'Bebidas Alcohólicas', 7.50, 6.00, 'packshots/cerveza_cusquena_dorada.png', 24.000),
                ('750106419173',  'Cerveza Corona Extra Six-Pack Botella 355ml', 'Corona', 'Bebidas Alcohólicas', 34.00, 27.50, 'packshots/cerveza_corona.png', 10.000),
                ('7750108003303', 'Leche Gloria Azul Evaporada Chica 170g', 'Gloria', 'Lácteos y Derivados', 2.40, 1.95, 'packshots/leche_gloria_azul.png', 36.000),
                ('7750108003310', 'Leche Gloria Azul Evaporada Six-Pack x6 Latas 400g', 'Gloria', 'Lácteos y Derivados', 24.00, 21.00, 'packshots/leche_gloria_azul.png', 12.000),
                ('7750108003327', 'Yogur Gloria Fresa Botella Personal 185g', 'Gloria', 'Lácteos y Derivados', 2.20, 1.70, 'packshots/yogur_gloria_fresa.png', 24.000),
                ('7750108003334', 'Yogur Gloria Vainilla Botella Personal 185g', 'Gloria', 'Lácteos y Derivados', 2.20, 1.70, 'packshots/yogur_gloria_vainilla.png', 24.000),
                ('7750108003341', 'Yogur Gloria Durazno Botella 1 Litro', 'Gloria', 'Lácteos y Derivados', 6.20, 5.00, 'packshots/yogur_gloria_vainilla_1kg.png', 16.000),
                ('7750115010301', 'Galleta Casino Menta 68g', 'Victoria', 'Golosinas y Chocolates', 1.00, 0.75, 'packshots/galleta_casino.png', 40.000),
                ('7750115010318', 'Galleta Casino Chocolate 68g', 'Victoria', 'Golosinas y Chocolates', 1.00, 0.75, 'packshots/galleta_casino.png', 40.000),
                ('7750115010325', 'Galleta Tentación Vainilla 70g', 'Victoria', 'Golosinas y Chocolates', 1.00, 0.75, 'packshots/galleta_tentacion.png', 40.000),
                ('7750115010332', 'Galleta Oreo Original Paquete x4 (36g)', 'Oreo', 'Golosinas y Chocolates', 1.20, 0.90, 'packshots/galleta_oreo.png', 40.000),
                ('7750115010349', 'Pastillas Halls Menta Eucalipto', 'Halls', 'Golosinas y Chocolates', 1.00, 0.70, 'packshots/halls_menta.png', 50.000),
                ('7750109004409', 'Arroz Extra Costeño Bolsa 5kg Familiar', 'Costeño', 'Abarrotes y Despensa', 21.50, 18.20, 'packshots/arroz_costeno.png', 12.000),
                ('7750109004416', 'Arroz Superior Faraón Bolsa 5kg Familiar', 'Faraón', 'Abarrotes y Despensa', 20.50, 17.50, 'packshots/arroz_faraon.png', 12.000),
                ('7750116011100', 'Avena Precocida 3 Ositos Bolsa Familiar 500g', '3 Ositos', 'Panadería y Desayuno', 3.80, 2.95, 'packshots/avena_tres_ositos.png', 24.000),
                ('7750116011117', 'Café Soluble Nescafé Tradición Doypack 50g', 'Nescafé', 'Panadería y Desayuno', 6.20, 4.90, 'packshots/cafe_nescafe.png', 18.000),
                ('7750114009305', 'Detergente Bolívar Blanco Activo Bolsa 450g', 'Bolívar', 'Limpieza y Cuidado del Hogar', 4.80, 3.80, 'packshots/detergente_bolivar.png', 20.000),
                ('7750114009312', 'Detergente Ace Limpieza Completa Bolsa 330g', 'Ace', 'Limpieza y Cuidado del Hogar', 3.80, 3.00, 'packshots/detergente_ace.png', 24.000),
                ('7750114009329', 'Lejía Clorox Tradicional Botella 680ml', 'Clorox', 'Limpieza y Cuidado del Hogar', 2.20, 1.70, 'packshots/lejia_clorox.png', 24.000),
                ('7750107002108', 'Hot Dog de Pollo San Fernando Económico 250g', 'San Fernando', 'Embutidos y Fiambrería', 3.20, 2.50, 'packshots/hot_dog_pollo.png', 20.000),
                ('7750107002115', 'Jamonada de Pollo San Fernando Económica 200g', 'San Fernando', 'Embutidos y Fiambrería', 3.50, 2.75, 'packshots/jamonada_pollo.png', 20.000)
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
            ELSIF v_cat_id IS NOT NULL THEN
                -- Si el producto ya existía (ej. Frugos Durazno o Cristal Lata con stock 0), asegurar stock > 0 e imagen
                UPDATE productos
                SET stock_actual = CASE WHEN stock_actual <= 0 THEN v_item.stock_ini ELSE stock_actual END,
                    imagen_url = CASE WHEN imagen_url IS NULL OR imagen_url = '' THEN v_item.img ELSE imagen_url END
                WHERE id_bodega = v_bodega_id AND codigo_barras = v_item.ean;
            END IF;
        END LOOP;
    END IF;
END $$;
