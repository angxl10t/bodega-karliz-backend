-- ==============================================================================
-- MIGRACIÓN V13: RESILIENCIA EN ALTA CONCURRENCIA, PREVENCIÓN DE STARVATION
-- Y OPTIMIZACIÓN MULTI-TIENDA PARA REPORTES Y ANALÍTICA BI
-- CajaYa Cloud POS Platform
-- ==============================================================================

-- 1. Indexación Foreign Key directa para 'ventas_detalles.id_venta'
-- Elimina Full Table Scans en joins de ventas y batch fetching de detalles
CREATE INDEX IF NOT EXISTS idx_ventas_detalles_id_venta 
    ON ventas_detalles(id_venta);

-- 2. Indexación Foreign Key directa para 'compras_detalles.id_compra'
CREATE INDEX IF NOT EXISTS idx_compras_detalles_id_compra 
    ON compras_detalles(id_compra);

-- 3. Índice compuesto para acelerar reportes de rotación y productos estrella
CREATE INDEX IF NOT EXISTS idx_ventas_detalles_prod_subtotal_cant 
    ON ventas_detalles(id_producto, subtotal, cantidad);

-- 4. Índice compuesto para ventas por bodega y fecha
CREATE INDEX IF NOT EXISTS idx_ventas_bodega_estado_fecha_total 
    ON ventas(id_bodega, estado, fecha_venta DESC);

-- 5. Índice parcial para inventario activo con stock positivo (Detección de Huesos / Valorización)
CREATE INDEX IF NOT EXISTS idx_productos_bodega_estado_stock 
    ON productos(id_bodega, estado, stock_actual) 
    WHERE estado = true AND stock_actual > 0;

-- 6. Índice para control de caducidades y alertas semáforo
CREATE INDEX IF NOT EXISTS idx_productos_bodega_vencimiento 
    ON productos(id_bodega, fecha_vencimiento) 
    WHERE estado = true AND fecha_vencimiento IS NOT NULL;
