-- ==========================================================================
-- MIGRACIÓN v18: SANITIZACIÓN DE CATEGORÍAS BASURA Y UNIFICACIÓN DE ATAJOS POS
-- Elimina 'Bebidas Refrescantes 128/342/431/556/658' y consolida duplicados
-- ==========================================================================

-- 1. Consolidar claves foráneas de los productos duplicados de Agua San Mateo (130, 132, 133, 134 -> 131)
DO $$
BEGIN
    UPDATE venta_detalles SET id_producto = 131 WHERE id_producto IN (130, 132, 133, 134);
    UPDATE compras_detalles SET id_producto = 131 WHERE id_producto IN (130, 132, 133, 134);
    UPDATE movimientos_inventario SET id_producto = 131 WHERE id_producto IN (130, 132, 133, 134);
    DELETE FROM productos WHERE id_producto IN (130, 132, 133, 134);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Consolidación de productos Agua San Mateo omitida o completada.';
END $$;

-- 2. Asegurar que las 12 categorías canónicas existan para todas las bodegas activas
INSERT INTO categorias (nombre, descripcion, estado, id_bodega)
SELECT c_def.nombre, c_def.descripcion, TRUE, b.id_bodega
FROM bodegas b
CROSS JOIN (
    VALUES 
        ('Gaseosas y Bebidas', 'Gaseosas, aguas minerales, jugos, néctares, energizantes e hidratantes'),
        ('Bebidas Alcohólicas', 'Cervezas, piscos, rones, vinos y licores'),
        ('Snacks y Piqueos', 'Papas fritas, chizitos, tortillas, platanitos y frutos secos'),
        ('Lácteos y Derivados', 'Leche evaporada, fresca, yogures, mantequillas, quesos y huevos'),
        ('Abarrotes y Despensa', 'Arroz, azúcar, fideos, aceites, conservas y condimentos'),
        ('Golosinas y Chocolates', 'Chocolates, galletas dulces, caramelos y confitería'),
        ('Embutidos y Fiambrería', 'Hot dogs, jamonadas, salchichas, tocinos y embutidos'),
        ('Panadería y Desayuno', 'Pan de molde, mermeladas, café, avena e infusiones'),
        ('Limpieza y Cuidado del Hogar', 'Detergentes, lejías, lavavajillas, suavizantes y esponjas'),
        ('Cuidado Personal y Dental', 'Cremas dentales, jabones, champús y papel higiénico'),
        ('Helados y Congelados', 'Helados en paleta, conos, bombones y potes familiares'),
        ('Cigarrillos y Tabaco', 'Cigarrillos en cajetilla, fósforos y encendedores')
) AS c_def(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM categorias c 
    WHERE c.id_bodega = b.id_bodega 
      AND LOWER(TRIM(c.nombre)) = LOWER(TRIM(c_def.nombre))
);

-- 3. Remapear cualquier producto asignado a categorías 'Bebidas Refrescantes%' hacia la canónica 'Gaseosas y Bebidas'
UPDATE productos p
SET id_categoria = c_dest.id_categoria
FROM categorias c_orig
JOIN categorias c_dest ON c_dest.id_bodega = c_orig.id_bodega AND c_dest.nombre = 'Gaseosas y Bebidas'
WHERE p.id_categoria = c_orig.id_categoria
  AND c_orig.nombre ILIKE 'Bebidas Refrescantes%'
  AND c_orig.id_categoria <> c_dest.id_categoria;

-- 4. Eliminar categorías basura 'Bebidas Refrescantes%'
DELETE FROM categorias WHERE nombre ILIKE 'Bebidas Refrescantes%';

-- 5. Unificar categorías redundantes por bodega
-- Bebidas / Bebidas y Gaseosas -> Gaseosas y Bebidas
UPDATE productos p
SET id_categoria = c_dest.id_categoria
FROM categorias c_orig
JOIN categorias c_dest ON c_dest.id_bodega = c_orig.id_bodega AND c_dest.nombre = 'Gaseosas y Bebidas'
WHERE p.id_categoria = c_orig.id_categoria
  AND (c_orig.nombre = 'Bebidas y Gaseosas' OR c_orig.nombre = 'Bebidas')
  AND c_orig.id_categoria <> c_dest.id_categoria;

-- Licores y Cervezas -> Bebidas Alcohólicas
UPDATE productos p
SET id_categoria = c_dest.id_categoria
FROM categorias c_orig
JOIN categorias c_dest ON c_dest.id_bodega = c_orig.id_bodega AND c_dest.nombre = 'Bebidas Alcohólicas'
WHERE p.id_categoria = c_orig.id_categoria
  AND c_orig.nombre = 'Licores y Cervezas'
  AND c_orig.id_categoria <> c_dest.id_categoria;

-- Snacks y Golosinas -> Snacks y Piqueos
UPDATE productos p
SET id_categoria = c_dest.id_categoria
FROM categorias c_orig
JOIN categorias c_dest ON c_dest.id_bodega = c_orig.id_bodega AND c_dest.nombre = 'Snacks y Piqueos'
WHERE p.id_categoria = c_orig.id_categoria
  AND c_orig.nombre = 'Snacks y Golosinas'
  AND c_orig.id_categoria <> c_dest.id_categoria;

-- Lácteos y Huevos -> Lácteos y Derivados
UPDATE productos p
SET id_categoria = c_dest.id_categoria
FROM categorias c_orig
JOIN categorias c_dest ON c_dest.id_bodega = c_orig.id_bodega AND c_dest.nombre = 'Lácteos y Derivados'
WHERE p.id_categoria = c_orig.id_categoria
  AND c_orig.nombre = 'Lácteos y Huevos'
  AND c_orig.id_categoria <> c_dest.id_categoria;

-- Abarrotes y Fideos -> Abarrotes y Despensa
UPDATE productos p
SET id_categoria = c_dest.id_categoria
FROM categorias c_orig
JOIN categorias c_dest ON c_dest.id_bodega = c_orig.id_bodega AND c_dest.nombre = 'Abarrotes y Despensa'
WHERE p.id_categoria = c_orig.id_categoria
  AND c_orig.nombre = 'Abarrotes y Fideos'
  AND c_orig.id_categoria <> c_dest.id_categoria;

-- Helados y Postres -> Helados y Congelados
UPDATE productos p
SET id_categoria = c_dest.id_categoria
FROM categorias c_orig
JOIN categorias c_dest ON c_dest.id_bodega = c_orig.id_bodega AND c_dest.nombre = 'Helados y Congelados'
WHERE p.id_categoria = c_orig.id_categoria
  AND c_orig.nombre = 'Helados y Postres'
  AND c_orig.id_categoria <> c_dest.id_categoria;

-- Cuidado Personal -> Cuidado Personal y Dental
UPDATE productos p
SET id_categoria = c_dest.id_categoria
FROM categorias c_orig
JOIN categorias c_dest ON c_dest.id_bodega = c_orig.id_bodega AND c_dest.nombre = 'Cuidado Personal y Dental'
WHERE p.id_categoria = c_orig.id_categoria
  AND c_orig.nombre = 'Cuidado Personal'
  AND c_orig.id_categoria <> c_dest.id_categoria;

-- Limpieza del Hogar -> Limpieza y Cuidado del Hogar
UPDATE productos p
SET id_categoria = c_dest.id_categoria
FROM categorias c_orig
JOIN categorias c_dest ON c_dest.id_bodega = c_orig.id_bodega AND c_dest.nombre = 'Limpieza y Cuidado del Hogar'
WHERE p.id_categoria = c_orig.id_categoria
  AND c_orig.nombre = 'Limpieza del Hogar'
  AND c_orig.id_categoria <> c_dest.id_categoria;

-- Cigarrillos y Tabacos -> Cigarrillos y Tabaco
UPDATE productos p
SET id_categoria = c_dest.id_categoria
FROM categorias c_orig
JOIN categorias c_dest ON c_dest.id_bodega = c_orig.id_bodega AND c_dest.nombre = 'Cigarrillos y Tabaco'
WHERE p.id_categoria = c_orig.id_categoria
  AND c_orig.nombre = 'Cigarrillos y Tabacos'
  AND c_orig.id_categoria <> c_dest.id_categoria;

-- 6. Purgar categorías redundantes que ya quedaron con 0 productos
DELETE FROM categorias
WHERE nombre IN (
    'Bebidas', 'Bebidas y Gaseosas', 'Licores y Cervezas', 'Snacks y Golosinas',
    'Lácteos y Huevos', 'Abarrotes y Fideos', 'Helados y Postres', 'Cuidado Personal',
    'Limpieza del Hogar', 'Cigarrillos y Tabacos'
)
AND id_categoria NOT IN (SELECT DISTINCT id_categoria FROM productos WHERE id_categoria IS NOT NULL);
