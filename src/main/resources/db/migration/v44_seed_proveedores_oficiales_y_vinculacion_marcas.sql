-- ==============================================================================
-- v44_seed_proveedores_oficiales_y_vinculacion_marcas.sql
-- Proveedores Oficiales del Mercado Bodeguero Peruano, Limpieza de Duplicados
-- Normalización de Marcas y Vinculación Sistemática de Catálogo
-- ==============================================================================

-- 1. Desactivar proveedores ficticios, duplicados o de prueba (como Mayorista Alianza S.A.C.)
UPDATE proveedores
SET estado = false,
    fecha_actualizacion = NOW()
WHERE estado = true
  AND (
      razon_social ILIKE '%mayorista alianza%'
      OR razon_social ILIKE '%alianza s%a%c%'
      OR ruc LIKE '20999%'
      OR ruc = '20123456789'
  );

-- 2. Función / Bloque anónimo para insertar proveedores oficiales canónicos por cada bodega existente
DO $$
DECLARE
    b_rec RECORD;
BEGIN
    FOR b_rec IN SELECT id_bodega FROM bodegas LOOP

        -- 1. ARCA CONTINENTAL LINDLEY (Coca-Cola, Inca Kola, Fanta, Sprite, San Luis, Frugos, Monster)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100107510', 'Arca Continental Lindley S.A. (Coca-Cola / Inca Kola)', 'Av. Javier Prado Este 4200, Santiago de Surco, Lima', '01-311-5000', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100107510' AND estado = true
        );

        -- 2. BACKUS Y JOHNSTON (Cristal, Pilsen Callao, Cusqueña, Corona, Guaraná, San Mateo)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100113610', 'Unión de Cervecerías Peruanas Backus y Johnston S.A.A.', 'Av. Nicolás Ayllón 3986, Ate, Lima', '01-311-3000', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100113610' AND estado = true
        );

        -- 3. ALICORP (Primor, Cocinero, AlaCena, Blanca Flor, Casino, Don Vittorio, Bolívar, Opal, Marsella)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100055237', 'Alicorp S.A.A. (Abarrotes, Aceites y Limpieza)', 'Av. Argentina 4793, Carmen de la Legua Reynoso, Callao', '01-315-0800', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100055237' AND estado = true
        );

        -- 4. GLORIA (Leche Gloria, Bonlé, Pura Vida, Tampico, Yogurt Gloria)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100190797', 'Leche Gloria S.A.', 'Av. República de Panamá 2461, La Victoria, Lima', '01-470-7170', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100190797' AND estado = true
        );

        -- 5. NESTLÉ PERÚ (Nescafé, Milo, Sublime, D''Onofrio, Triángulo, Princesa, Maggi, Ideal)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100177072', 'Nestlé Perú S.A. (Lácteos, Chocolates y Helados)', 'Calle Luis Galvani 493, Urb. Industrial Vulcano, Ate, Lima', '0800-10-210', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100177072' AND estado = true
        );

        -- 6. MONDELEZ PERÚ (Oreo, Club Social, Ritz, Field, Doña Pepa, Cua Cua, Trident, Halls)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100122978', 'Mondelez Perú S.A. (Kraft / Field / Nabisco)', 'Av. Venezuela 2470, Bellavista, Callao', '01-219-4000', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100122978' AND estado = true
        );

        -- 7. PEPSICO ALIMENTOS PERÚ / CBC (Lay''s, Doritos, Cheetos, Piqueo Snack, Cuates, Karinto, Pepsi, 7Up)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20297868790', 'Pepsico Alimentos Perú S.R.L. / CBC', 'Av. Francisco Bolognesi 505, Santa Anita, Lima', '01-618-2000', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20297868790' AND estado = true
        );

        -- 8. AJEPER (Kola Real, KR, Cielo, Cifrut, Sporade, Pulp, Volt, Free Tea)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20331061901', 'Ajeper S.A. (Grupo AJE - Big Cola / KR / Sporade)', 'Av. Los Conquistadores 1144, San Isidro, Lima', '01-211-5300', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20331061901' AND estado = true
        );

        -- 9. SAN FERNANDO (Jamonada, Hot Dog, Salchicha, Tocino, Nuggets, Huevos)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100154308', 'San Fernando S.A. (Embutidos, Aves y Huevos)', 'Av. República de Panamá 4295, Surquillo, Lima', '01-213-5300', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100154308' AND estado = true
        );

        -- 10. BRAEDT / OTTO KUNZ (Embutidos finos, Jamón del País, Salchichas, Chorizos)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100030595', 'Braedt S.A. (Fiambrería Fina & Otto Kunz)', 'Av. Elmer Faucett 474, Carmen de la Legua, Callao', '01-517-1800', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100030595' AND estado = true
        );

        -- 11. LAIVE (Leche, Quesos, Mantequilla, Yogurt, Jamonada)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100095451', 'Laive S.A. (Lácteos y Fiambrería)', 'Av. Nicolás Hermoza 115, Ate, Lima', '01-619-3600', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100095451' AND estado = true
        );

        -- 12. BIMBO DEL PERÚ (Pan de molde, Pan hamburguesa, Tortillas, Marinela)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20383070465', 'Bimbo del Perú S.A. (Panadería y Desayuno)', 'Av. Venezuela 2470, Cercado de Lima', '01-315-7700', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20383070465' AND estado = true
        );

        -- 13. MOLITALIA (Fideos Molitalia, Todinno, Costa, Ambrosoli, Fanny, 3 Ositos)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100035121', 'Molitalia S.A. (Fideos, Harinas y Confitería)', 'Av. Venezuela 2850, Cercado de Lima', '01-513-5000', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100035121' AND estado = true
        );

        -- 14. PROCTER & GAMBLE (Ace, Ariel, Ayudín, Pantene, Head & Shoulders, Gillette, Oral-B)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100127163', 'Procter & Gamble del Perú S.R.L. (P&G)', 'Av. República de Colombia 791, San Isidro, Lima', '0800-55-791', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100127163' AND estado = true
        );

        -- 15. COLGATE-PALMOLIVE (Colgate, Kolynos, Protex, Palmolive, Suavitel, Speed Stick)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100097151', 'Colgate-Palmolive Perú S.A.', 'Av. Juan de Arona 151, San Isidro, Lima', '01-211-3700', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100097151' AND estado = true
        );

        -- 16. KIMBERLY-CLARK (Suave, Scott, Huggies, Kotex, Kleenex, Plenitud)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20227929424', 'Kimberly-Clark Perú S.R.L. (Papelería y Cuidado)', 'Av. Elmer Faucett 356, Callao', '01-614-2200', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20227929424' AND estado = true
        );

        -- 17. SOFTYS PERÚ (Elite, Noble, Premier, Babysec, Ladysoft)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20265219981', 'Softys Perú S.A. (Elite / Papelería Institucional)', 'Av. Santa Rosa 350, Santa Anita, Lima', '01-317-2000', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20265219981' AND estado = true
        );

        -- 18. CLOROX PERÚ (Clorox, Poett)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100119227', 'Clorox Perú S.A. (Desinfección y Limpieza)', 'Av. Los Frutales 419, Ate, Lima', '01-617-6400', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100119227' AND estado = true
        );

        -- 19. RINTI (Ricocan, Ricocat, Thor, Supercan, Dogui, Mimaskot)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100141664', 'Rinti S.A. (Ricocan & Ricocat Alimento Balanceado)', 'Av. Minerales 540, Cercado de Lima', '01-619-0200', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100141664' AND estado = true
        );

        -- 20. COSTEÑO ALIMENTOS (Arroz Costeño, Menestras, Paisana, Faraón, Valle Norte)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100070970', 'Costeño Alimentos S.A.C. (Arroz y Menestras)', 'Carretera Central Km 18.2, Chaclacayo, Lima', '01-317-5000', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100070970' AND estado = true
        );

        -- 21. SIBARITA DEL PERÚ (Ajo Siba, Amarillito, Tuco Sibarita, Panca, Orégano)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100155207', 'Sibarita del Perú S.A. (Condimentos y Especias)', 'Jr. Antonio Polo 741, Pueblo Libre, Lima', '01-461-1222', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100155207' AND estado = true
        );

        -- 22. AJINOMOTO DEL PERÚ (Ajinomoto, Doña Gusta, Aji-no-sillao, Aji-no-men)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100085063', 'Ajinomoto del Perú S.A. (Sazonadores y Caldos)', 'Av. República de Panamá 2455, La Victoria, Lima', '01-615-5400', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100085063' AND estado = true
        );

        -- 23. BRITISH AMERICAN TOBACCO (Lucky Strike, Pall Mall, Hamilton, Kent)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100008824', 'British American Tobacco del Perú S.A.C. (BAT)', 'Av. Rivera Navarrete 501, San Isidro, Lima', '01-611-3000', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100008824' AND estado = true
        );

        -- 24. PHILIP MORRIS PERÚ (Marlboro, L&M, Chesterfield)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20456428606', 'Philip Morris Perú S.R.L. (Marlboro & Tabacos)', 'Av. Santo Toribio 173, San Isidro, Lima', '01-610-8500', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20456428606' AND estado = true
        );

        -- 25. BODEGAS Y VIÑEDOS TABERNERO (Tabernero, Santiago Queirolo, Portón, Cartavio)
        INSERT INTO proveedores (id_bodega, ruc, razon_social, direccion, telefono, estado, fecha_creacion, fecha_actualizacion)
        SELECT b_rec.id_bodega, '20100010993', 'Bodegas y Viñedos Tabernero S.A.C. (Piscos y Licores)', 'Av. Grau 430, Miraflores, Lima', '01-446-8800', true, NOW(), NOW()
        WHERE NOT EXISTS (
            SELECT 1 FROM proveedores WHERE id_bodega = b_rec.id_bodega AND ruc = '20100010993' AND estado = true
        );

    END LOOP;
END $$;

-- 3. Normalización y corrección estricta de marcas en toda la tabla productos
UPDATE productos SET marca = 'AlaCena' WHERE marca ILIKE 'alacena' OR nombre ILIKE '%AlaCena%';
UPDATE productos SET marca = 'Coca-Cola' WHERE marca IN ('Coca Cola', 'coca cola', 'Coca-Cola') OR (marca IS NULL AND nombre ILIKE '%Coca Cola%');
UPDATE productos SET marca = 'Inca Kola' WHERE marca IN ('Inka Kola', 'inca kola') OR (marca IS NULL AND nombre ILIKE '%Inca Kola%');
UPDATE productos SET marca = 'Lay''s' WHERE marca IN ('Lays', 'lays', 'Frito-Lay') AND (nombre ILIKE '%Lay''s%' OR nombre ILIKE '%Lays%');
UPDATE productos SET marca = 'Nestlé' WHERE marca IN ('Nestle', 'nestle') OR (marca IS NULL AND nombre ILIKE '%Nestlé%');
UPDATE productos SET marca = 'Bolívar' WHERE marca IN ('Bolivar', 'bolivar') OR (marca IS NULL AND nombre ILIKE '%Bolívar%' OR nombre ILIKE '%Bolivar%');
UPDATE productos SET marca = 'Ángel' WHERE marca IN ('Angel', 'angel') OR (marca IS NULL AND nombre ILIKE '%Ángel%');
UPDATE productos SET marca = 'Bonlé' WHERE marca IN ('Bonle', 'bonle') OR (marca IS NULL AND nombre ILIKE '%Bonlé%' OR nombre ILIKE '%Bonle%');
UPDATE productos SET marca = 'D''Onofrio' WHERE marca IN ('Donofrio', 'donofrio', 'D', 'Onofrio') OR nombre ILIKE '%D''Onofrio%' OR nombre ILIKE '%Donofrio%';
UPDATE productos SET marca = 'Marlboro' WHERE marca IN ('Malboro', 'malboro') OR nombre ILIKE '%Marlboro%' OR nombre ILIKE '%Malboro%';
UPDATE productos SET marca = 'San Mateo' WHERE marca IN ('San-Mateo', 'san mateo') OR nombre ILIKE '%San Mateo%';
UPDATE productos SET marca = 'San Luis' WHERE marca IN ('San-Luis', 'san luis') OR nombre ILIKE '%San Luis%';
UPDATE productos SET marca = '7Up' WHERE marca IN ('7 Up', '7-Up', 'seven up') OR nombre ILIKE '%7Up%' OR nombre ILIKE '%7 Up%';
UPDATE productos SET marca = 'Ayudín' WHERE marca ILIKE 'ayudin' OR nombre ILIKE '%Ayudín%' OR nombre ILIKE '%Ayudin%';
UPDATE productos SET marca = 'Pilsen Callao' WHERE marca ILIKE 'pilsen' OR nombre ILIKE '%Pilsen Callao%';

-- 4. Vinculación inteligente y sistemática de cada producto a su proveedor habitual
-- 4.1 ARCA CONTINENTAL LINDLEY
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100107510'
  AND prov.estado = true
  AND (
      p.marca IN ('Coca-Cola', 'Inca Kola', 'Fanta', 'Sprite', 'San Luis', 'Frugos', 'Monster Energy', 'Powerade', 'Schweppes')
      OR p.nombre ILIKE '%Coca Cola%' OR p.nombre ILIKE '%Inca Kola%' OR p.nombre ILIKE '%Fanta%'
      OR p.nombre ILIKE '%Sprite%' OR p.nombre ILIKE '%San Luis%' OR p.nombre ILIKE '%Frugos%'
  );

-- 4.2 BACKUS Y JOHNSTON
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100113610'
  AND prov.estado = true
  AND (
      p.marca IN ('Cristal', 'Pilsen Callao', 'Cusqueña', 'Corona', 'Guaraná', 'San Mateo', 'Stella Artois', 'Budweiser', 'Maltin Power', 'Mike''s', 'Backus')
      OR p.nombre ILIKE '%Pilsen%' OR p.nombre ILIKE '%Cristal%' OR p.nombre ILIKE '%Cusqueña%'
      OR p.nombre ILIKE '%Corona%' OR p.nombre ILIKE '%Guaraná Backus%' OR p.nombre ILIKE '%San Mateo%'
  );

-- 4.3 ALICORP
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100055237'
  AND prov.estado = true
  AND (
      p.marca IN ('Primor', 'Cocinero', 'Cil', 'Nicolini', 'Don Vittorio', 'Lavaggi', 'AlaCena', 'Blanca Flor', 'Casino', 'Tentación', 'Glacitas', 'Chocman', 'Bolívar', 'Opal', 'Marsella', 'Trome', 'Patito', 'Amor', 'Sayón', 'Alicorp', 'Victoria')
      OR p.nombre ILIKE '%Primor%' OR p.nombre ILIKE '%AlaCena%' OR p.nombre ILIKE '%Don Vittorio%'
      OR p.nombre ILIKE '%Bolívar%' OR p.nombre ILIKE '%Opal%' OR p.nombre ILIKE '%Blanca Flor%'
      OR p.nombre ILIKE '%Galleta Casino%' OR p.nombre ILIKE '%Glacitas%'
  );

-- 4.4 LECHE GLORIA
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100190797'
  AND prov.estado = true
  AND (
      p.marca IN ('Gloria', 'Bonlé', 'Pura Vida', 'Tampico')
      OR p.nombre ILIKE '%Leche Gloria%' OR p.nombre ILIKE '%Yogurt Gloria%'
      OR p.nombre ILIKE '%Bonlé%' OR p.nombre ILIKE '%Pura Vida%'
  );

-- 4.5 NESTLÉ PERÚ
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100177072'
  AND prov.estado = true
  AND (
      p.marca IN ('Nestlé', 'Nescafé', 'Milo', 'Sublime', 'D''Onofrio', 'Triángulo', 'Princesa', 'Maggi', 'Ideal', 'KitKat', 'Kirma', 'Ecco')
      OR p.nombre ILIKE '%Sublime%' OR p.nombre ILIKE '%D''Onofrio%' OR p.nombre ILIKE '%Nescafé%'
      OR p.nombre ILIKE '%Milo%' OR p.nombre ILIKE '%Maggi%' OR p.nombre ILIKE '%Ideal%'
  );

-- 4.6 MONDELEZ PERÚ
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100122978'
  AND prov.estado = true
  AND (
      p.marca IN ('Oreo', 'Club Social', 'Ritz', 'Chips Ahoy!', 'Field', 'Doña Pepa', 'Cua Cua', 'Soda Field', 'Vainilla Field', 'Charada', 'Trident', 'Halls', 'Bubbaloo', 'Tang', 'Clight')
      OR p.nombre ILIKE '%Oreo%' OR p.nombre ILIKE '%Club Social%' OR p.nombre ILIKE '%Doña Pepa%'
      OR p.nombre ILIKE '%Cua Cua%' OR p.nombre ILIKE '%Soda Field%'
  );

-- 4.7 PEPSICO ALIMENTOS PERÚ / CBC
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20297868790'
  AND prov.estado = true
  AND (
      p.marca IN ('Lay''s', 'Doritos', 'Cheetos', 'Piqueo Snack', 'Cuates', 'Tortees', 'Chizitos', 'Karinto', 'Pepsi', '7Up', 'Concordia', 'Gatorade', 'Evervess')
      OR p.nombre ILIKE '%Lay''s%' OR p.nombre ILIKE '%Doritos%' OR p.nombre ILIKE '%Cheetos%'
      OR p.nombre ILIKE '%Piqueo Snack%' OR p.nombre ILIKE '%Pepsi%' OR p.nombre ILIKE '%7Up%'
  );

-- 4.8 AJEPER (GRUPO AJE)
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20331061901'
  AND prov.estado = true
  AND (
      p.marca IN ('Kola Real', 'KR', 'Big Cola', 'Cielo', 'Cifrut', 'Sporade', 'Pulp', 'Free Tea', 'Volt')
      OR p.nombre ILIKE '%Kola Real%' OR p.nombre ILIKE '%Cifrut%' OR p.nombre ILIKE '%Sporade%'
      OR p.nombre ILIKE '%Agua Cielo%' OR p.nombre ILIKE '%Volt%'
  );

-- 4.9 SAN FERNANDO
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100154308'
  AND prov.estado = true
  AND (
      p.marca IN ('San Fernando')
      OR p.nombre ILIKE '%San Fernando%' OR p.nombre ILIKE '%Jamonada San Fernando%'
      OR p.nombre ILIKE '%Hot Dog San Fernando%' OR p.nombre ILIKE '%Huevos%'
  );

-- 4.10 BRAEDT / OTTO KUNZ
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100030595'
  AND prov.estado = true
  AND (
      p.marca IN ('Braedt', 'Otto Kunz')
      OR p.nombre ILIKE '%Braedt%' OR p.nombre ILIKE '%Otto Kunz%'
  );

-- 4.11 LAIVE
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100095451'
  AND prov.estado = true
  AND (
      p.marca IN ('Laive')
      OR p.nombre ILIKE '%Laive%'
  );

-- 4.12 BIMBO
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20383070465'
  AND prov.estado = true
  AND (
      p.marca IN ('Bimbo', 'Marinela')
      OR p.nombre ILIKE '%Bimbo%' OR p.nombre ILIKE '%Marinela%'
  );

-- 4.13 MOLITALIA
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100035121'
  AND prov.estado = true
  AND (
      p.marca IN ('Molitalia', 'San Remo', 'Todinno', 'Costa', 'Ambrosoli', 'Fanny', '3 Ositos')
      OR p.nombre ILIKE '%Molitalia%' OR p.nombre ILIKE '%Costa%' OR p.nombre ILIKE '%Ambrosoli%'
      OR p.nombre ILIKE '%Fanny%' OR p.nombre ILIKE '%3 Ositos%'
  );

-- 4.14 PROCTER & GAMBLE
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100127163'
  AND prov.estado = true
  AND (
      p.marca IN ('Ace', 'Ariel', 'Downy', 'Ayudín', 'Pantene', 'Head & Shoulders', 'Gillette', 'Oral-B')
      OR p.nombre ILIKE '%Ace%' OR p.nombre ILIKE '%Ariel%' OR p.nombre ILIKE '%Ayudín%'
      OR p.nombre ILIKE '%Pantene%' OR p.nombre ILIKE '%Head & Shoulders%'
  );

-- 4.15 COLGATE-PALMOLIVE
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100097151'
  AND prov.estado = true
  AND (
      p.marca IN ('Colgate', 'Kolynos', 'Protex', 'Palmolive', 'Suavitel', 'Speed Stick')
      OR p.nombre ILIKE '%Colgate%' OR p.nombre ILIKE '%Kolynos%' OR p.nombre ILIKE '%Protex%'
  );

-- 4.16 KIMBERLY-CLARK
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20227929424'
  AND prov.estado = true
  AND (
      p.marca IN ('Suave', 'Scott', 'Kleenex', 'Huggies', 'Kotex', 'Plenitud')
      OR p.nombre ILIKE '%Suave%' OR p.nombre ILIKE '%Huggies%' OR p.nombre ILIKE '%Kotex%'
  );

-- 4.17 SOFTYS PERÚ
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20265219981'
  AND prov.estado = true
  AND (
      p.marca IN ('Elite', 'Noble', 'Premier', 'Babysec', 'Ladysoft', 'Paracas')
      OR p.nombre ILIKE '%Elite%' OR p.nombre ILIKE '%Paracas%'
  );

-- 4.18 CLOROX
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100119227'
  AND prov.estado = true
  AND (
      p.marca IN ('Clorox', 'Poett')
      OR p.nombre ILIKE '%Clorox%' OR p.nombre ILIKE '%Poett%'
  );

-- 4.19 RINTI (MASCOTAS)
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100141664'
  AND prov.estado = true
  AND (
      p.marca IN ('Ricocan', 'Ricocat', 'Thor', 'Supercan', 'Bandido', 'Dogui', 'Mimaskot', 'Pedigree', 'Dog Chow', 'Whiskas', 'Felix')
      OR p.nombre ILIKE '%Ricocan%' OR p.nombre ILIKE '%Ricocat%' OR p.nombre ILIKE '%Mimaskot%'
  );

-- 4.20 COSTEÑO ALIMENTOS
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100070970'
  AND prov.estado = true
  AND (
      p.marca IN ('Costeño', 'Paisana', 'Faraón', 'Valle Norte')
      OR p.nombre ILIKE '%Costeño%' OR p.nombre ILIKE '%Paisana%' OR p.nombre ILIKE '%Faraón%'
  );

-- 4.21 SIBARITA
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100155207'
  AND prov.estado = true
  AND (
      p.marca IN ('Sibarita')
      OR p.nombre ILIKE '%Sibarita%'
  );

-- 4.22 AJINOMOTO
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100085063'
  AND prov.estado = true
  AND (
      p.marca IN ('Ajinomoto', 'Doña Gusta', 'Aji-no-sillao', 'Aji-no-men')
      OR p.nombre ILIKE '%Ajinomoto%' OR p.nombre ILIKE '%Doña Gusta%'
  );

-- 4.23 BRITISH AMERICAN TOBACCO
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100008824'
  AND prov.estado = true
  AND (
      p.marca IN ('Lucky Strike', 'Pall Mall', 'Hamilton', 'Kent')
      OR p.nombre ILIKE '%Lucky Strike%' OR p.nombre ILIKE '%Pall Mall%' OR p.nombre ILIKE '%Hamilton%'
  );

-- 4.24 PHILIP MORRIS
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20456428606'
  AND prov.estado = true
  AND (
      p.marca IN ('Marlboro', 'L&M', 'Chesterfield')
      OR p.nombre ILIKE '%Marlboro%' OR p.nombre ILIKE '%Malboro%'
  );

-- 4.25 TABERNERO Y QUEIROLO
UPDATE productos p
SET id_proveedor = prov.id_proveedor
FROM proveedores prov
WHERE prov.id_bodega = p.id_bodega
  AND prov.ruc = '20100010993'
  AND prov.estado = true
  AND (
      p.marca IN ('Tabernero', 'Santiago Queirolo', 'Portón', 'Cartavio')
      OR p.nombre ILIKE '%Tabernero%' OR p.nombre ILIKE '%Santiago Queirolo%' OR p.nombre ILIKE '%Cartavio%'
  );

-- 5. Garantizar stock operativo y comercial real para Bodega Karliz en todos sus productos
UPDATE productos
SET stock_actual = 18.000
WHERE id_bodega IN (
    SELECT id_bodega FROM bodegas WHERE UPPER(nombre_comercial) LIKE '%KARLIZ%'
)
AND (stock_actual IS NULL OR stock_actual = 0);
