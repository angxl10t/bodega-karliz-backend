-- ==============================================================================
-- MIGRACIÓN V10: ACELERACIÓN DE CONSULTAS Y OPTIMIZACIÓN DE RENDIMIENTO
-- CajaYa Cloud POS Platform - Índices Especializados y Cobertura de Turnos
-- ==============================================================================

-- 1. Aceleración del Kardex Global por Bodega en orden cronológico inverso
-- Permite que findTop200ByBodega_IdBodegaOrderByFechaMovimientoDesc resuelva directamente
-- con Index Scan sin requerir un SORT en memoria o disco.
CREATE INDEX IF NOT EXISTS idx_mov_bodega_fecha 
    ON movimientos_inventario(id_bodega, fecha_movimiento DESC);

-- 2. Aceleración de Egresos de Caja Chica activos por Bodega y Rango de Fechas
-- Optimiza findByBodega_IdBodegaAndFechaEgresoBetweenAndEstadoTrueOrderByFechaEgresoDesc
CREATE INDEX IF NOT EXISTS idx_egresos_caja_bodega_estado_fecha 
    ON egresos_caja(id_bodega, estado, fecha_egreso DESC);

-- 3. Aceleración de Ventas por Estado y Fecha
-- Optimiza el filtrado de ventas COMPLETADAS / ANULADAS y el cálculo de arqueo diario
CREATE INDEX IF NOT EXISTS idx_ventas_bodega_estado_fecha 
    ON ventas(id_bodega, estado, fecha_venta DESC);

-- 4. Aceleración de Presentaciones activas por Bodega y Producto
CREATE INDEX IF NOT EXISTS idx_presentaciones_bodega_prod_estado 
    ON presentaciones(id_bodega, id_producto, estado);
