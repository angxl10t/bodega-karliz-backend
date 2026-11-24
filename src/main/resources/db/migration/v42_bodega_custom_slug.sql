-- v42_bodega_custom_slug.sql: Agregar columna slug único a bodegas para URLs personalizadas en catálogo web
ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS slug VARCHAR(100);

-- Índice único insensible a mayúsculas para búsquedas de alta velocidad
CREATE UNIQUE INDEX IF NOT EXISTS idx_bodegas_slug ON bodegas (LOWER(slug)) WHERE slug IS NOT NULL AND estado = true;
