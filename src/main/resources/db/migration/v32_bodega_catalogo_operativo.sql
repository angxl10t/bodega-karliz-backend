-- ==============================================================================
-- Migración v32: Configuración operativa del Catálogo Digital "Mi Bodega Online"
-- Agrega las columnas catalogo_abierto y delivery_activo a la tabla bodegas
-- de forma 100% idempotente para entornos PostgreSQL / Supabase con ddl-auto=none.
-- ==============================================================================

ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS catalogo_abierto BOOLEAN DEFAULT TRUE;
ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS delivery_activo BOOLEAN DEFAULT TRUE;

UPDATE bodegas SET catalogo_abierto = TRUE WHERE catalogo_abierto IS NULL;
UPDATE bodegas SET delivery_activo = TRUE WHERE delivery_activo IS NULL;
