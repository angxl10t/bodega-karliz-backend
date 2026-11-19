-- ==============================================================================
-- Migración v40: Soporte Multinegocio (Giro de Negocio en Bodegas) y PIN para Cajeros.
-- Giros admitidos: BODEGA, POLLERIA, CHIFA, FASTFOOD, RESTAURANTE, GENERAL.
-- 100% Idempotente y seguro para producción.
-- ==============================================================================

-- 1. Agregar columna giro_negocio a la tabla bodegas
ALTER TABLE bodegas 
ADD COLUMN IF NOT EXISTS giro_negocio VARCHAR(30) DEFAULT 'BODEGA';

-- Detección inteligente de giro por nombre para negocios creados previamente
UPDATE bodegas 
SET giro_negocio = 'POLLERIA' 
WHERE (giro_negocio IS NULL OR giro_negocio = 'BODEGA') 
  AND (nombre_comercial ILIKE '%poller%' OR nombre_comercial ILIKE '%brasa%');

UPDATE bodegas 
SET giro_negocio = 'CHIFA' 
WHERE (giro_negocio IS NULL OR giro_negocio = 'BODEGA') 
  AND (nombre_comercial ILIKE '%chifa%' OR nombre_comercial ILIKE '%oriental%');

UPDATE bodegas 
SET giro_negocio = 'FASTFOOD' 
WHERE (giro_negocio IS NULL OR giro_negocio = 'BODEGA') 
  AND (nombre_comercial ILIKE '%fast%' OR nombre_comercial ILIKE '%burger%' OR nombre_comercial ILIKE '%sanguch%');

-- Actualizar bodegas restantes que tengan null a BODEGA
UPDATE bodegas 
SET giro_negocio = 'BODEGA' 
WHERE giro_negocio IS NULL;

-- 2. Agregar columna pin a la tabla usuarios (para autenticación ágil en terminales POS)
ALTER TABLE usuarios 
ADD COLUMN IF NOT EXISTS pin VARCHAR(100);

-- 3. Crear índice para optimizar búsquedas por terminal y PIN
CREATE INDEX IF NOT EXISTS idx_usuarios_bodega_pin 
ON usuarios (id_bodega, pin) 
WHERE pin IS NOT NULL;

-- 4. Crear índice para búsquedas por giro de negocio
CREATE INDEX IF NOT EXISTS idx_bodegas_giro_negocio 
ON bodegas (giro_negocio);

-- 5. Purgar productos de bodega inyectados erróneamente en locales gastronómicos
-- (solo productos sin ventas, compras ni movimientos que no corresponden al giro de comida/restaurante)
DELETE FROM productos 
WHERE id_bodega IN (SELECT id_bodega FROM bodegas WHERE UPPER(COALESCE(giro_negocio, '')) IN ('POLLERIA', 'CHIFA', 'FASTFOOD'))
  AND (
    codigo_barras IN (SELECT codigo_barras FROM catalogo_starter_pack_global)
    OR (codigo_barras NOT LIKE 'POL%' AND codigo_barras NOT LIKE 'CHF%' AND codigo_barras NOT LIKE 'FF%')
  )
  AND id_producto NOT IN (SELECT id_producto FROM ventas_detalles WHERE id_producto IS NOT NULL)
  AND id_producto NOT IN (SELECT id_producto FROM compras_detalles WHERE id_producto IS NOT NULL)
  AND id_producto NOT IN (SELECT id_producto FROM movimientos_inventario WHERE id_producto IS NOT NULL);

-- 6. Eliminar categorías vacías de bodega en locales gastronómicos
DELETE FROM categorias
WHERE id_bodega IN (SELECT id_bodega FROM bodegas WHERE UPPER(COALESCE(giro_negocio, '')) IN ('POLLERIA', 'CHIFA', 'FASTFOOD'))
  AND nombre IN (
    'Abarrotes y Despensa', 'Lácteos y Derivados', 'Snacks y Piqueos', 'Panadería y Desayuno',
    'Limpieza y Cuidado del Hogar', 'Cuidado Personal y Dental', 'Helados y Congelados',
    'Bebidas Alcohólicas', 'Cigarrillos y Tabaco', 'Golosinas y Dulces', 'Embutidos y Fiambres'
  )
  AND id_categoria NOT IN (SELECT DISTINCT id_categoria FROM productos WHERE id_categoria IS NOT NULL);
