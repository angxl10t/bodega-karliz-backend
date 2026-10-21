-- Migración V11: Soporte de imágenes para productos (Catálogo Fijo y Cargas de Bodegueros)
ALTER TABLE productos ADD COLUMN IF NOT EXISTS imagen_url VARCHAR(500);
