-- =========================================================================
-- MIGRACIÓN V30: AUDITORÍA EN KARDEX DE CAMBIOS DE PRECIOS, DESCRIPCIÓN Y DATOS
-- Permite registrar eventos de trazabilidad cuando el administrador modifica
-- precios de venta, costos, nombres/descripciones, categorías o marcas.
-- =========================================================================

ALTER TABLE IF EXISTS movimientos_inventario 
    ALTER COLUMN tipo_movimiento TYPE VARCHAR(50);
