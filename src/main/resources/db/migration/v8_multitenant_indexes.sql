-- ==============================================================================
-- MIGRACIÓN V8: ÍNDICES COMPUESTOS MULTI-TENANT Y OPTIMIZACIÓN DE RENDIMIENTO
-- CajaYa Cloud POS Platform - Aceleración de Consultas y Prevención de Full Table Scans
-- ==============================================================================

-- 1. Aceleración de listado de ventas por bodega y fecha descendente
CREATE INDEX IF NOT EXISTS idx_ventas_bodega_fecha 
    ON ventas(id_bodega, fecha_venta DESC);

-- 2. Búsqueda instantánea de idempotencia por bodega
CREATE INDEX IF NOT EXISTS idx_ventas_bodega_idemp 
    ON ventas(id_bodega, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- 3. Aceleración de listado de compras por bodega y fecha
CREATE INDEX IF NOT EXISTS idx_compras_bodega_fecha 
    ON compras(id_bodega, fecha_compra DESC);

-- 4. Búsqueda de compras por proveedor y bodega
CREATE INDEX IF NOT EXISTS idx_compras_bodega_proveedor 
    ON compras(id_bodega, id_proveedor);

-- 5. Aceleración de Kardex por bodega, producto y fecha
CREATE INDEX IF NOT EXISTS idx_mov_bodega_prod_fecha 
    ON movimientos_inventario(id_bodega, id_producto, fecha_movimiento DESC);
