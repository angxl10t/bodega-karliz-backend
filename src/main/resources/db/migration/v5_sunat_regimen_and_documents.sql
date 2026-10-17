-- ==============================================================================
-- MIGRACIÓN V5: RÉGIMEN TRIBUTARIO SUNAT Y CONTROL DE COMPROBANTES
-- CajaYa Cloud POS Platform - Regulación Tributaria Peruana
-- ==============================================================================

-- 1. Agregar columna regimen_tributario en la tabla bodegas si no existe
ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS regimen_tributario VARCHAR(30) DEFAULT 'NUEVO_RUS';

-- 2. Asegurar que las bodegas existentes tengan un régimen válido
UPDATE bodegas SET regimen_tributario = 'NUEVO_RUS' WHERE regimen_tributario IS NULL;

-- Asignar a Bodega KARLIZ MYPE_TRIBUTARIO para permitirle emitir Facturas y Boletas
UPDATE bodegas SET regimen_tributario = 'MYPE_TRIBUTARIO' WHERE id_bodega = 3 OR nombre_comercial ILIKE '%KARLIZ%';

-- 3. Constraint CHECK para los regímenes tributarios oficiales en el Perú
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_bodegas_regimen_tributario'
    ) THEN
        ALTER TABLE bodegas ADD CONSTRAINT chk_bodegas_regimen_tributario 
        CHECK (regimen_tributario IN ('NUEVO_RUS', 'RER', 'MYPE_TRIBUTARIO', 'REGIMEN_GENERAL'));
    END IF;
END $$;

-- 4. Índice para búsquedas y filtros por régimen tributario
CREATE INDEX IF NOT EXISTS idx_bodegas_regimen_tributario ON bodegas(regimen_tributario);
