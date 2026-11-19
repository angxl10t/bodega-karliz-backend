-- ==============================================================================
-- Migración v40: Soporte Multinegocio (Giro de Negocio en Bodegas) y PIN para Cajeros.
-- Giros admitidos: BODEGA, POLLERIA, CHIFA, FASTFOOD, RESTAURANTE, GENERAL.
-- 100% Idempotente y seguro para producción.
-- ==============================================================================

-- 1. Agregar columna giro_negocio a la tabla bodegas
ALTER TABLE bodegas 
ADD COLUMN IF NOT EXISTS giro_negocio VARCHAR(30) DEFAULT 'BODEGA';

-- Actualizar bodegas existentes que tengan null
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
