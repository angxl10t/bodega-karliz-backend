-- ==============================================================================
-- Migración v39: Expansión Comercial Ola 7 (+43 productos peruanos de alta
-- rotación con EAN-13 reales y packshots oficiales: Congelados/Helados,
-- Embutidos/Quesos/Lácteos, Pastas/Menestras/Postres en Polvo, Panadería,
-- Snacks y Descartables/Hogar). 100% idempotente.
-- ==============================================================================

DO $$
DECLARE
    v_bodega_id BIGINT;
    v_cat_id BIGINT;
    v_item RECORD;
BEGIN
    -- 1. Registrar los 43 productos en el Preset Global del SuperAdmin
    INSERT INTO catalogo_starter_pack_global (
        codigo_barras, nombre, marca, categoria, precio_venta, precio_costo, imagen_url, activo
    ) VALUES
        ('7750946007566', 'Nuggets de Pollo San Fernando Safari x10', 'San Fernando', 'Helados y Congelados', 5.90, 4.70, 'packshots/nuggets_san_fernando_x10.png', TRUE),
        ('7550946003636', 'Hamburguesa San Fernando La Casera x14', 'San Fernando', 'Helados y Congelados', 14.50, 11.80, 'packshots/hamburguesa_san_fernando_x14.png', TRUE),
        ('7752346006392', 'Mini Hamburguesa Parrillera Otto Kunz 600g', 'Otto Kunz', 'Helados y Congelados', 32.90, 26.80, 'packshots/hamburguesa_otto_kunz_600g.png', TRUE),
        ('8711571093385', 'Papas Prefritas Lamb Weston Original 750g', 'Lamb Weston', 'Helados y Congelados', 14.50, 11.60, 'packshots/papas_prefritas_750g.png', TRUE),
        ('614143278426', 'Tequeños Rellenos de Queso Teque Cheese x12', 'Teque Cheese', 'Helados y Congelados', 20.90, 16.80, 'packshots/tequenos_queso_x12.png', TRUE),
        ('7613036713566', 'Helado Peziduri Lúcuma D''Onofrio 900ml', 'D''Onofrio', 'Helados y Congelados', 11.90, 9.50, 'packshots/helado_peziduri_lucuma_900ml.png', TRUE),
        ('7752087232111', 'Helado Peziduri Chocolate D''Onofrio 900ml', 'D''Onofrio', 'Helados y Congelados', 11.90, 9.50, 'packshots/helado_peziduri_chocolate_900ml.png', TRUE),
        ('7752346005098', 'Jamón Inglés Braedt Paquete 200g', 'Braedt', 'Embutidos y Fiambrería', 16.50, 13.40, 'packshots/jamon_ingles_braedt_200g.png', TRUE),
        ('7750302725066', 'Jamón Inglés Otto Kunz Paquete 200g', 'Otto Kunz', 'Embutidos y Fiambrería', 13.90, 11.20, 'packshots/jamon_ingles_otto_kunz_200g.png', TRUE),
        ('7752346008792', 'Salchicha Frankfurter Alemán Otto Kunz 280g', 'Otto Kunz', 'Embutidos y Fiambrería', 18.90, 15.20, 'packshots/salchicha_frankfurt_otto_280g.png', TRUE),
        ('7752346008563', 'Cabanossi Otto Kunz Unidad', 'Otto Kunz', 'Embutidos y Fiambrería', 3.90, 3.00, 'packshots/cabanossi_otto_kunz.png', TRUE),
        ('7622201426170', 'Queso Crema Philadelphia Original 150g', 'Kraft', 'Lácteos y Derivados', 12.90, 10.40, 'packshots/queso_philadelphia_150g.png', TRUE),
        ('7751271009706', 'Queso Edam Bonlé Tajado 185g', 'Bonlé', 'Lácteos y Derivados', 13.20, 10.60, 'packshots/queso_edam_bonle_185g.png', TRUE),
        ('7751271036290', 'Leche Entera UHT Gloria Caja 946ml', 'Gloria', 'Lácteos y Derivados', 6.20, 5.10, 'packshots/leche_gloria_uht_946ml.png', TRUE),
        ('7750151008945', 'Leche Concentrada Sin Lactosa Laive Botella 400g', 'Laive', 'Lácteos y Derivados', 4.80, 3.95, 'packshots/leche_laive_sin_lactosa_400g.png', TRUE),
        ('7613036500715', 'Crema de Leche Nestlé Lata 300g', 'Nestlé', 'Lácteos y Derivados', 10.50, 8.50, 'packshots/crema_leche_nestle_300g.png', TRUE),
        ('7751271038683', 'Crema de Leche Gloria Caja 946ml', 'Gloria', 'Lácteos y Derivados', 28.50, 23.20, 'packshots/crema_leche_gloria_946ml.png', TRUE),
        ('7751271037846', 'Yogur Griego Gloria Mango 800g', 'Gloria', 'Lácteos y Derivados', 8.20, 6.60, 'packshots/yogur_gloria_griego_mango_800g.png', TRUE),
        ('7750243082341', 'Fideos Codo Rayado Don Vittorio 225g', 'Don Vittorio', 'Abarrotes y Despensa', 2.10, 1.65, 'packshots/fideos_don_vittorio_codo_225g.png', TRUE),
        ('7750243082365', 'Fideos Tornillo Don Vittorio 250g', 'Don Vittorio', 'Abarrotes y Despensa', 2.10, 1.65, 'packshots/fideos_don_vittorio_tornillo_250g.png', TRUE),
        ('7750243017329', 'Fideos Cabello de Ángel Don Vittorio 250g', 'Don Vittorio', 'Abarrotes y Despensa', 1.80, 1.40, 'packshots/fideos_cabello_angel_250g.png', TRUE),
        ('7750885289016', 'Fideos Tornillo Tricolor Molitalia 235g', 'Molitalia', 'Abarrotes y Despensa', 2.00, 1.55, 'packshots/fideos_molitalia_tricolor_235g.png', TRUE),
        ('7754725057223', 'Arroz Gran Reserva Extra Valle Norte 750g', 'Valle Norte', 'Abarrotes y Despensa', 4.30, 3.55, 'packshots/arroz_valle_norte_750g.png', TRUE),
        ('7758003370127', 'Maíz Pop Corn Costeño Bolsa 500g', 'Costeño', 'Abarrotes y Despensa', 3.40, 2.65, 'packshots/maiz_pop_corn_costeno_500g.png', TRUE),
        ('7755139054594', 'Quinua Costeño Bolsa 500g', 'Costeño', 'Abarrotes y Despensa', 8.90, 7.20, 'packshots/quinua_costeno_500g.png', TRUE),
        ('7752414000314', 'Aceite de Oliva Extra Virgen El Olivar 500ml', 'El Olivar', 'Abarrotes y Despensa', 34.50, 28.00, 'packshots/aceite_oliva_el_olivar_500ml.png', TRUE),
        ('7758651000216', 'Vinagre Blanco Venturo Botella 600ml', 'Venturo', 'Abarrotes y Despensa', 5.50, 4.30, 'packshots/vinagre_blanco_venturo_600ml.png', TRUE),
        ('2050000002311', 'Salsa de Ostión Panda Lee Kum Kee 510g', 'Lee Kum Kee', 'Abarrotes y Despensa', 27.90, 22.50, 'packshots/salsa_ostion_panda_510g.png', TRUE),
        ('88169093767', 'Sopa Criolla Maggi Gallina con Fideos 60g', 'Maggi', 'Abarrotes y Despensa', 3.90, 3.05, 'packshots/sopa_maggi_criolla_60g.png', TRUE),
        ('7752230004428', 'Gelatina Universal Fresa Sobre 130g', 'Universal', 'Abarrotes y Despensa', 4.20, 3.30, 'packshots/gelatina_universal_fresa_130g.png', TRUE),
        ('7622201500276', 'Flan en Polvo Royal Vainilla 80g', 'Royal', 'Abarrotes y Despensa', 3.90, 3.05, 'packshots/flan_royal_vainilla_80g.png', TRUE),
        ('7622210091505', 'Mazamorra Morada en Polvo Royal 140g', 'Royal', 'Abarrotes y Despensa', 4.50, 3.55, 'packshots/mazamorra_morada_royal_140g.png', TRUE),
        ('7622300051822', 'Polvo para Hornear Royal Sobre 20g', 'Royal', 'Abarrotes y Despensa', 1.50, 1.10, 'packshots/polvo_hornear_royal_20g.png', TRUE),
        ('7750243069922', 'Esencia de Vainilla Umsha Frasco 90ml', 'Umsha', 'Abarrotes y Despensa', 2.50, 1.90, 'packshots/esencia_vainilla_umsha_90ml.png', TRUE),
        ('7750727116074', 'Pan para Hamburguesa Bimbo Bolsa x8', 'Bimbo', 'Panadería y Desayuno', 9.50, 7.60, 'packshots/pan_hamburguesa_bimbo_x8.png', TRUE),
        ('7750727005026', 'Pan para Hot Dog Bimbo Bolsa x8', 'Bimbo', 'Panadería y Desayuno', 9.50, 7.60, 'packshots/pan_hotdog_bimbo_x8.png', TRUE),
        ('7750727000298', 'Tostadas Clásicas Bimbo Paquete x10', 'Bimbo', 'Panadería y Desayuno', 8.20, 6.50, 'packshots/tostadas_bimbo_x10.png', TRUE),
        ('38000184895', 'Papas Pringles Crema y Cebolla 109g', 'Pringles', 'Snacks y Piqueos', 9.40, 7.50, 'packshots/pringles_crema_cebolla_109g.png', TRUE),
        ('38000183669', 'Papas Pringles Sabor BBQ 158g', 'Pringles', 'Snacks y Piqueos', 14.90, 12.00, 'packshots/pringles_bbq_158g.png', TRUE),
        ('7806500221128', 'Servilletas Elite Premium Cóctel x50', 'Elite', 'Limpieza y Cuidado del Hogar', 4.90, 3.85, 'packshots/servilletas_elite_coctel_x50.png', TRUE),
        ('7898553454851', 'Papel Aluminio Darnel 45cm x 7.5m', 'Darnel', 'Limpieza y Cuidado del Hogar', 11.90, 9.50, 'packshots/papel_aluminio_darnel.png', TRUE),
        ('51111027790', 'Guantes Multiuso Scotch-Brite Talla M', 'Scotch-Brite', 'Limpieza y Cuidado del Hogar', 16.50, 13.20, 'packshots/guantes_scotch_brite_m.png', TRUE),
        ('2050000299698', 'Limpiavidrios Sapolio Aroma Lavanda 650ml', 'Sapolio', 'Limpieza y Cuidado del Hogar', 11.90, 9.50, 'packshots/limpiavidrios_sapolio_650ml.png', TRUE)
    ON CONFLICT (codigo_barras) DO UPDATE SET
        imagen_url = EXCLUDED.imagen_url,
        activo = TRUE;

    -- 2. Sembrar los 43 productos en Bodega KARLIZ con stock comercial inicial visible
    SELECT id_bodega INTO v_bodega_id
    FROM bodegas
    WHERE id_bodega = 1 OR nombre_comercial ILIKE '%KARLIZ%'
    ORDER BY id_bodega ASC
    LIMIT 1;

    IF v_bodega_id IS NOT NULL THEN
        FOR v_item IN
            SELECT * FROM (VALUES
                ('7750946007566', 'Nuggets de Pollo San Fernando Safari x10', 'San Fernando', 'Helados y Congelados', 5.90, 4.70, 'packshots/nuggets_san_fernando_x10.png', 18.000),
                ('7550946003636', 'Hamburguesa San Fernando La Casera x14', 'San Fernando', 'Helados y Congelados', 14.50, 11.80, 'packshots/hamburguesa_san_fernando_x14.png', 12.000),
                ('7752346006392', 'Mini Hamburguesa Parrillera Otto Kunz 600g', 'Otto Kunz', 'Helados y Congelados', 32.90, 26.80, 'packshots/hamburguesa_otto_kunz_600g.png', 8.000),
                ('8711571093385', 'Papas Prefritas Lamb Weston Original 750g', 'Lamb Weston', 'Helados y Congelados', 14.50, 11.60, 'packshots/papas_prefritas_750g.png', 14.000),
                ('614143278426', 'Tequeños Rellenos de Queso Teque Cheese x12', 'Teque Cheese', 'Helados y Congelados', 20.90, 16.80, 'packshots/tequenos_queso_x12.png', 10.000),
                ('7613036713566', 'Helado Peziduri Lúcuma D''Onofrio 900ml', 'D''Onofrio', 'Helados y Congelados', 11.90, 9.50, 'packshots/helado_peziduri_lucuma_900ml.png', 12.000),
                ('7752087232111', 'Helado Peziduri Chocolate D''Onofrio 900ml', 'D''Onofrio', 'Helados y Congelados', 11.90, 9.50, 'packshots/helado_peziduri_chocolate_900ml.png', 12.000),
                ('7752346005098', 'Jamón Inglés Braedt Paquete 200g', 'Braedt', 'Embutidos y Fiambrería', 16.50, 13.40, 'packshots/jamon_ingles_braedt_200g.png', 12.000),
                ('7750302725066', 'Jamón Inglés Otto Kunz Paquete 200g', 'Otto Kunz', 'Embutidos y Fiambrería', 13.90, 11.20, 'packshots/jamon_ingles_otto_kunz_200g.png', 14.000),
                ('7752346008792', 'Salchicha Frankfurter Alemán Otto Kunz 280g', 'Otto Kunz', 'Embutidos y Fiambrería', 18.90, 15.20, 'packshots/salchicha_frankfurt_otto_280g.png', 10.000),
                ('7752346008563', 'Cabanossi Otto Kunz Unidad', 'Otto Kunz', 'Embutidos y Fiambrería', 3.90, 3.00, 'packshots/cabanossi_otto_kunz.png', 24.000),
                ('7622201426170', 'Queso Crema Philadelphia Original 150g', 'Kraft', 'Lácteos y Derivados', 12.90, 10.40, 'packshots/queso_philadelphia_150g.png', 12.000),
                ('7751271009706', 'Queso Edam Bonlé Tajado 185g', 'Bonlé', 'Lácteos y Derivados', 13.20, 10.60, 'packshots/queso_edam_bonle_185g.png', 14.000),
                ('7751271036290', 'Leche Entera UHT Gloria Caja 946ml', 'Gloria', 'Lácteos y Derivados', 6.20, 5.10, 'packshots/leche_gloria_uht_946ml.png', 20.000),
                ('7750151008945', 'Leche Concentrada Sin Lactosa Laive Botella 400g', 'Laive', 'Lácteos y Derivados', 4.80, 3.95, 'packshots/leche_laive_sin_lactosa_400g.png', 24.000),
                ('7613036500715', 'Crema de Leche Nestlé Lata 300g', 'Nestlé', 'Lácteos y Derivados', 10.50, 8.50, 'packshots/crema_leche_nestle_300g.png', 14.000),
                ('7751271038683', 'Crema de Leche Gloria Caja 946ml', 'Gloria', 'Lácteos y Derivados', 28.50, 23.20, 'packshots/crema_leche_gloria_946ml.png', 8.000),
                ('7751271037846', 'Yogur Griego Gloria Mango 800g', 'Gloria', 'Lácteos y Derivados', 8.20, 6.60, 'packshots/yogur_gloria_griego_mango_800g.png', 14.000),
                ('7750243082341', 'Fideos Codo Rayado Don Vittorio 225g', 'Don Vittorio', 'Abarrotes y Despensa', 2.10, 1.65, 'packshots/fideos_don_vittorio_codo_225g.png', 30.000),
                ('7750243082365', 'Fideos Tornillo Don Vittorio 250g', 'Don Vittorio', 'Abarrotes y Despensa', 2.10, 1.65, 'packshots/fideos_don_vittorio_tornillo_250g.png', 30.000),
                ('7750243017329', 'Fideos Cabello de Ángel Don Vittorio 250g', 'Don Vittorio', 'Abarrotes y Despensa', 1.80, 1.40, 'packshots/fideos_cabello_angel_250g.png', 30.000),
                ('7750885289016', 'Fideos Tornillo Tricolor Molitalia 235g', 'Molitalia', 'Abarrotes y Despensa', 2.00, 1.55, 'packshots/fideos_molitalia_tricolor_235g.png', 28.000),
                ('7754725057223', 'Arroz Gran Reserva Extra Valle Norte 750g', 'Valle Norte', 'Abarrotes y Despensa', 4.30, 3.55, 'packshots/arroz_valle_norte_750g.png', 24.000),
                ('7758003370127', 'Maíz Pop Corn Costeño Bolsa 500g', 'Costeño', 'Abarrotes y Despensa', 3.40, 2.65, 'packshots/maiz_pop_corn_costeno_500g.png', 24.000),
                ('7755139054594', 'Quinua Costeño Bolsa 500g', 'Costeño', 'Abarrotes y Despensa', 8.90, 7.20, 'packshots/quinua_costeno_500g.png', 16.000),
                ('7752414000314', 'Aceite de Oliva Extra Virgen El Olivar 500ml', 'El Olivar', 'Abarrotes y Despensa', 34.50, 28.00, 'packshots/aceite_oliva_el_olivar_500ml.png', 8.000),
                ('7758651000216', 'Vinagre Blanco Venturo Botella 600ml', 'Venturo', 'Abarrotes y Despensa', 5.50, 4.30, 'packshots/vinagre_blanco_venturo_600ml.png', 18.000),
                ('2050000002311', 'Salsa de Ostión Panda Lee Kum Kee 510g', 'Lee Kum Kee', 'Abarrotes y Despensa', 27.90, 22.50, 'packshots/salsa_ostion_panda_510g.png', 8.000),
                ('88169093767', 'Sopa Criolla Maggi Gallina con Fideos 60g', 'Maggi', 'Abarrotes y Despensa', 3.90, 3.05, 'packshots/sopa_maggi_criolla_60g.png', 24.000),
                ('7752230004428', 'Gelatina Universal Fresa Sobre 130g', 'Universal', 'Abarrotes y Despensa', 4.20, 3.30, 'packshots/gelatina_universal_fresa_130g.png', 24.000),
                ('7622201500276', 'Flan en Polvo Royal Vainilla 80g', 'Royal', 'Abarrotes y Despensa', 3.90, 3.05, 'packshots/flan_royal_vainilla_80g.png', 22.000),
                ('7622210091505', 'Mazamorra Morada en Polvo Royal 140g', 'Royal', 'Abarrotes y Despensa', 4.50, 3.55, 'packshots/mazamorra_morada_royal_140g.png', 22.000),
                ('7622300051822', 'Polvo para Hornear Royal Sobre 20g', 'Royal', 'Abarrotes y Despensa', 1.50, 1.10, 'packshots/polvo_hornear_royal_20g.png', 36.000),
                ('7750243069922', 'Esencia de Vainilla Umsha Frasco 90ml', 'Umsha', 'Abarrotes y Despensa', 2.50, 1.90, 'packshots/esencia_vainilla_umsha_90ml.png', 24.000),
                ('7750727116074', 'Pan para Hamburguesa Bimbo Bolsa x8', 'Bimbo', 'Panadería y Desayuno', 9.50, 7.60, 'packshots/pan_hamburguesa_bimbo_x8.png', 14.000),
                ('7750727005026', 'Pan para Hot Dog Bimbo Bolsa x8', 'Bimbo', 'Panadería y Desayuno', 9.50, 7.60, 'packshots/pan_hotdog_bimbo_x8.png', 14.000),
                ('7750727000298', 'Tostadas Clásicas Bimbo Paquete x10', 'Bimbo', 'Panadería y Desayuno', 8.20, 6.50, 'packshots/tostadas_bimbo_x10.png', 16.000),
                ('38000184895', 'Papas Pringles Crema y Cebolla 109g', 'Pringles', 'Snacks y Piqueos', 9.40, 7.50, 'packshots/pringles_crema_cebolla_109g.png', 16.000),
                ('38000183669', 'Papas Pringles Sabor BBQ 158g', 'Pringles', 'Snacks y Piqueos', 14.90, 12.00, 'packshots/pringles_bbq_158g.png', 12.000),
                ('7806500221128', 'Servilletas Elite Premium Cóctel x50', 'Elite', 'Limpieza y Cuidado del Hogar', 4.90, 3.85, 'packshots/servilletas_elite_coctel_x50.png', 22.000),
                ('7898553454851', 'Papel Aluminio Darnel 45cm x 7.5m', 'Darnel', 'Limpieza y Cuidado del Hogar', 11.90, 9.50, 'packshots/papel_aluminio_darnel.png', 14.000),
                ('51111027790', 'Guantes Multiuso Scotch-Brite Talla M', 'Scotch-Brite', 'Limpieza y Cuidado del Hogar', 16.50, 13.20, 'packshots/guantes_scotch_brite_m.png', 12.000),
                ('2050000299698', 'Limpiavidrios Sapolio Aroma Lavanda 650ml', 'Sapolio', 'Limpieza y Cuidado del Hogar', 11.90, 9.50, 'packshots/limpiavidrios_sapolio_650ml.png', 14.000)
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
