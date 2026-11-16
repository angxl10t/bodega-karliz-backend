-- =========================================================================
-- MIGRACIÓN V31: FIX AUDITORÍA KARDEX (DESACOPLAR VISTA Y EXPANDIR COLUMNA)
-- Desacopla la vista v_kardex_general para permitir ALTER COLUMN tipo_movimiento TYPE VARCHAR(50)
-- y la recrea garantizando security_invoker = true.
-- =========================================================================

DROP VIEW IF EXISTS public.v_kardex_general CASCADE;

ALTER TABLE IF EXISTS public.movimientos_inventario 
    ALTER COLUMN tipo_movimiento TYPE VARCHAR(50);

CREATE OR REPLACE VIEW public.v_kardex_general AS
SELECT 
    m.id_movimiento,
    m.id_bodega,
    b.nombre_comercial AS bodega,
    p.id_producto,
    p.codigo,
    p.codigo_barras,
    p.nombre AS producto,
    m.tipo_movimiento,
    m.cantidad,
    m.motivo,
    m.usuario_responsable,
    m.fecha_movimiento
FROM public.movimientos_inventario m
LEFT JOIN public.productos p ON p.id_producto = m.id_producto
LEFT JOIN public.bodegas b ON b.id_bodega = m.id_bodega;

ALTER VIEW IF EXISTS public.v_kardex_general SET (security_invoker = true);
