-- ==========================================================================
-- MIGRACIÓN v19: ELIMINACIÓN DE RESTRICCIONES LEGACY SINGLE-TENANT
-- Permite que múltiples bodegas registren productos con los mismos códigos de barra
-- y SKUs (aislamiento multi-tenant estricto mediante uk_productos_bodega_codigo y
-- uk_productos_bodega_codigo_barras).
-- ==========================================================================

DO $$
BEGIN
    -- 1. Eliminar restricciones únicas globales heredadas en 'productos'
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'ukb2vi4382tjm9b8q2sgfiox2ec' AND table_name = 'productos'
    ) THEN
        ALTER TABLE productos DROP CONSTRAINT ukb2vi4382tjm9b8q2sgfiox2ec;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'ukh04wpyqwddobltuqq56cp6s05' AND table_name = 'productos'
    ) THEN
        ALTER TABLE productos DROP CONSTRAINT ukh04wpyqwddobltuqq56cp6s05;
    END IF;

    -- 2. Eliminar restricciones únicas globales heredadas en 'proveedores'
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'ukl2qkpg6gem3abown28yrhqjph' AND table_name = 'proveedores'
    ) THEN
        ALTER TABLE proveedores DROP CONSTRAINT ukl2qkpg6gem3abown28yrhqjph;
    END IF;

    -- 3. Eliminar índices únicos de una sola columna si persisten
    DROP INDEX IF EXISTS ukb2vi4382tjm9b8q2sgfiox2ec;
    DROP INDEX IF EXISTS ukh04wpyqwddobltuqq56cp6s05;
    DROP INDEX IF EXISTS ukl2qkpg6gem3abown28yrhqjph;

    -- 4. Asegurar que los índices y restricciones multi-tenant existan y estén activos
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'uk_productos_bodega_codigo' AND table_name = 'productos'
    ) THEN
        ALTER TABLE productos ADD CONSTRAINT uk_productos_bodega_codigo UNIQUE (id_bodega, codigo);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'uk_productos_bodega_codigo_barras' AND table_name = 'productos'
    ) THEN
        ALTER TABLE productos ADD CONSTRAINT uk_productos_bodega_codigo_barras UNIQUE (id_bodega, codigo_barras);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'uk_proveedores_bodega_ruc' AND table_name = 'proveedores'
    ) THEN
        ALTER TABLE proveedores ADD CONSTRAINT uk_proveedores_bodega_ruc UNIQUE (id_bodega, ruc);
    END IF;

    RAISE NOTICE 'Restricciones legacy single-tenant eliminadas y multi-tenancy verificado.';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Aviso en migración v19: %', SQLERRM;
END $$;
