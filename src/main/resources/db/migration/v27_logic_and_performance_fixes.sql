-- =============================================================================
-- v27: Integridad transaccional, unicidad de comprobantes e índices compuestos
-- =============================================================================

-- 1. Yape/Plin: Limpiar duplicados históricos priorizando transacciones ya canjeadas
DELETE FROM yape_transacciones_recibidas a
USING yape_transacciones_recibidas b
WHERE a.codigo_operacion = b.codigo_operacion
  AND (
    (a.usado = false AND b.usado = true)
    OR (a.usado = b.usado AND a.id_transaccion > b.id_transaccion)
  );

CREATE UNIQUE INDEX IF NOT EXISTS uq_yape_transaccion_codigo_op
    ON yape_transacciones_recibidas (codigo_operacion);

-- Índice único parcial global por código de operación en pagos de suscripción
CREATE UNIQUE INDEX IF NOT EXISTS uq_pagos_suscripcion_codigo_op
    ON pagos_suscripcion (UPPER(TRIM(codigo_operacion)))
    WHERE codigo_operacion IS NOT NULL AND TRIM(codigo_operacion) <> '';

-- 2. Boletas consolidadas Nuevo RUS: única boleta diaria por bodega
DELETE FROM boletas_consolidadas a
USING boletas_consolidadas b
WHERE a.id_bodega = b.id_bodega
  AND a.fecha_emision = b.fecha_emision
  AND a.id_boleta_consolidada < b.id_boleta_consolidada;

CREATE UNIQUE INDEX IF NOT EXISTS uq_boletas_consolidadas_bodega_fecha
    ON boletas_consolidadas (id_bodega, fecha_emision);

-- 3. Clientes: evitar DNI/RUC activos duplicados por concurrencia dentro de la misma bodega
CREATE UNIQUE INDEX IF NOT EXISTS uq_clientes_bodega_documento_activo
    ON clientes (id_bodega, LOWER(TRIM(documento)))
    WHERE estado = true AND documento IS NOT NULL AND TRIM(documento) <> '';

-- 4. Índices compuestos para consultas de cuenta corriente, pagos y catálogo
CREATE INDEX IF NOT EXISTS idx_ventas_bodega_cliente_fecha
    ON ventas (id_bodega, id_cliente, fecha_venta DESC);

CREATE INDEX IF NOT EXISTS idx_abonos_bodega_cliente_fecha
    ON abonos_credito (id_bodega, id_cliente, fecha_abono DESC);

CREATE INDEX IF NOT EXISTS idx_reclamaciones_bodega_fecha
    ON reclamaciones (id_bodega, fecha_reclamo DESC);

CREATE INDEX IF NOT EXISTS idx_pagos_suscripcion_bodega_fecha
    ON pagos_suscripcion (id_bodega, fecha_pago DESC);

CREATE INDEX IF NOT EXISTS idx_productos_bodega_estado_codigo
    ON productos (id_bodega, estado, codigo);
