-- ==========================================================================
-- MIGRACIÓN v17: CORRECCIÓN EXHAUSTIVA DE TAMAÑOS (GRAMOS, ML, LITROS)
-- Y ENLACE DE FOTOGRAFÍAS OFICIALES PACKSHOTS EN PRODUCTOS COMERCIALES
-- ==========================================================================

DO $$
BEGIN
    -- 1. Bebidas y Gaseosas: separar 500ml vs 3 Litros con packshots dedicados
    UPDATE productos
    SET nombre = 'Inca Kola Sabor Original 500ml',
        imagen_url = 'packshots/inka_kola_500ml.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7750106001010', '7750106000018')
       OR (nombre ILIKE '%Inca Kola%500%' AND imagen_url = 'packshots/inka_kola.png');

    UPDATE productos
    SET nombre = 'Inca Kola Sabor Original 3 Litros',
        imagen_url = 'packshots/inka_kola_3l.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7750106000013', '7750182001243')
       OR (nombre ILIKE '%Inca Kola%3%L%');

    UPDATE productos
    SET nombre = 'Coca Cola Sabor Original 500ml',
        imagen_url = 'packshots/coca_cola_500ml.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras = '7750106000025'
       OR (nombre ILIKE '%Coca Cola%500%');

    UPDATE productos
    SET nombre = 'Coca Cola Sabor Original 3 Litros',
        imagen_url = 'packshots/coca_cola_3l.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7751234567890', '7750106002024', '7750182001250')
       OR (nombre ILIKE '%Coca Cola%3%L%');

    UPDATE productos
    SET nombre = 'Gaseosa Fanta Naranja 500ml',
        imagen_url = 'packshots/fanta_500ml.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7750182220378', '7750106004011')
       OR (nombre ILIKE '%Fanta%500%');

    UPDATE productos
    SET nombre = 'Gaseosa Fanta Naranja 3 Litros',
        imagen_url = 'packshots/fanta_3l.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7750182495301', '7750106004028')
       OR (nombre ILIKE '%Fanta%3%L%');

    UPDATE productos
    SET nombre = 'Gaseosa Sprite Lima Limón 500ml',
        imagen_url = 'packshots/sprite_500ml.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7750182000321', '7750106005018')
       OR (nombre ILIKE '%Sprite%500%');

    UPDATE productos
    SET nombre = 'Gaseosa Sprite Lima Limón 3 Litros',
        imagen_url = 'packshots/sprite_3l.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7750182000222', '7750106005025')
       OR (nombre ILIKE '%Sprite%3%L%');

    UPDATE productos
    SET nombre = 'Gaseosa Guaraná Backus 450ml',
        imagen_url = 'packshots/guarana_450ml.png',
        marca = 'Backus',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7753749003186', '7750106007012')
       OR (nombre ILIKE '%Guaraná%');

    UPDATE productos
    SET nombre = 'Agua Mineral San Mateo Sin Gas 600ml',
        imagen_url = 'packshots/agua_san_mateo_600ml.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('77530967', '775117011953', '775386598917')
       OR (nombre ILIKE '%San Mateo%');

    UPDATE productos
    SET nombre = 'Agua San Luis Sin Gas Bidón con Caño 7 Litros',
        imagen_url = 'packshots/agua_san_luis.png',
        fecha_actualizacion = NOW()
    WHERE imagen_url = 'packshots/agua_san_luis.png';

    -- 2. Snacks y Piqueos
    UPDATE productos
    SET nombre = 'Papas Fritas Lay''s Clásicas Sal Bolsa 140g',
        imagen_url = 'packshots/lays_clasicas_140g.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7758574005541', '7750106009999', '7750106009982')
       OR (nombre ILIKE '%Lay%Clásica%');

    UPDATE productos
    SET nombre = 'Snack Piqueo Snax Original Bolsa 55g',
        imagen_url = 'packshots/piqueo_snax_55g.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7758574004230', '7750106009968')
       OR (nombre ILIKE '%Piqueo Snax%');

    UPDATE productos
    SET nombre = 'Snack Cheese Tris Queso Bolsa 44g',
        imagen_url = 'packshots/cheese_tris_44g.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7758574005619', '7750106009944', '7750106009937')
       OR (nombre ILIKE '%Cheese Tris%');

    UPDATE productos
    SET nombre = 'Tortilla Chips Doritos Queso Atrevido 45g',
        imagen_url = 'packshots/doritos_queso_45g.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7758574004445', '7750106009951')
       OR (nombre ILIKE '%Doritos%Queso%');

    UPDATE productos
    SET nombre = 'Hojuelas de Maíz Los Cuates Picante 100g',
        imagen_url = 'packshots/cuates_picantes_100g.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7750106009913', '7750106009906')
       OR (nombre ILIKE '%Cuates%Picante%');

    -- 3. Lácteos y Chocolates
    UPDATE productos
    SET nombre = 'Leche Chocolatada Gloria UHT Caja 946ml',
        imagen_url = 'packshots/leche_chocolatada_gloria.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7750108003051', '7750108003150')
       OR (nombre ILIKE '%Chocolatada%Gloria%');

    UPDATE productos
    SET nombre = 'Chocolate con Leche Sublime Clásico Tableta 100g',
        imagen_url = 'packshots/chocolate_sublime.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7613036615303', '7750115010011', '7750115010110')
       OR (nombre ILIKE '%Sublime%Clásico%');

    UPDATE productos
    SET nombre = 'Yogurt Bebible Gloria Fresa Botella 1Kg',
        imagen_url = 'packshots/yogur_gloria_fresa.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7750108003068', '7750108003082')
       OR (nombre ILIKE '%Yogur%Gloria%Fresa%');

    UPDATE productos
    SET nombre = 'Yogurt Gloria Vainilla Botella 1Kg',
        imagen_url = 'packshots/yogur_gloria_vainilla.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7751271033718', '7750108003075')
       OR (nombre ILIKE '%Yogur%Gloria%Vainilla%');

    -- 4. Abarrotes, Limpieza y Cuidados
    UPDATE productos
    SET nombre = 'Mayonesa AlaCena Regular Doypack 850g',
        marca = 'AlaCena',
        imagen_url = 'packshots/mayonesa_alacena.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7750243072366', '7750109004164', '7750109004190')
       OR (nombre ILIKE '%Mayonesa%AlaCena%');

    UPDATE productos
    SET nombre = 'Crema de Ají Tarí AlaCena Doypack 400g',
        marca = 'AlaCena',
        imagen_url = 'packshots/crema_tari.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7750243030335', '7750109004140', '7750114009146')
       OR (nombre ILIKE '%Tarí%');

    UPDATE productos
    SET nombre = 'Trozos de Atún en Aceite Vegetal Fanny 140g',
        imagen_url = 'packshots/atun_fanny.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7750885020343', '7750109004089')
       OR (nombre ILIKE '%Fanny%');

    UPDATE productos
    SET nombre = 'Lavavajilla Líquido Ayudín Lima Limón 900ml',
        imagen_url = 'packshots/lavavajilla_ayudin.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7759918006163', '7750114009077', '7750114009213')
       OR (nombre ILIKE '%Ayudín%');

    UPDATE productos
    SET nombre = 'Cigarrillos Marlboro Summer Mix Cajetilla 20',
        marca = 'Marlboro',
        imagen_url = 'packshots/cigarros_marlboro_20.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7751201001169', '7750112007011')
       OR (nombre ILIKE '%Hamilton%')
       OR (nombre ILIKE '%Marlboro%');

    UPDATE productos
    SET nombre = 'Helado Peziduri Tricolor D''Onofrio Pote 900ml',
        imagen_url = 'packshots/helado_peziduri_tricolor.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7613287023568', '7750110005048')
       OR (nombre ILIKE '%Peziduri%Tricolor%');

    UPDATE productos
    SET nombre = 'Helado Frío Rico D''Onofrio Multipack Vainilla Caja x4',
        imagen_url = 'packshots/helado_frio_rico.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7613287065261', '7750110005031')
       OR (nombre ILIKE '%Frío Rico%');

    UPDATE productos
    SET nombre = 'Pan de Molde Bimbo Blanco Familiar 590g',
        imagen_url = 'packshots/pan_bimbo_blanco.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7750727014189', '7750116011018', '7750116011117')
       OR (nombre ILIKE '%Bimbo Blanco%');

    UPDATE productos
    SET nombre = 'Cerveza Cristal Lata 355ml',
        imagen_url = 'packshots/cerveza_cristal_lata.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7753749001984', '7750111006212');

    UPDATE productos
    SET nombre = 'Cerveza Cusqueña Dorada Botella 310ml',
        imagen_url = 'packshots/cerveza_cusquena_dorada.png',
        fecha_actualizacion = NOW()
    WHERE codigo_barras IN ('7753749005357', '7750106006022');
END $$;
