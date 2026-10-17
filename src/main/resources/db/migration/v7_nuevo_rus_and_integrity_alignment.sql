-- ==============================================================================
-- MIGRACIÓN V7: ALINEACIÓN EXCLUSIVA NUEVO RUS, ROBUSTEZ TELEMÁTICA Y AUDITORÍA DE CAJA
-- CajaYa Cloud POS Platform - Régimen Tributario Nuevo RUS & Resiliencia SUNAT
-- ==============================================================================

-- 1. ALINEACIÓN AL RÉGIMEN NUEVO RUS PARA TODAS LAS BODEGAS
-- En el Nuevo RUS los negocios emiten exclusivamente Boletas de Venta y Tickets de control.
UPDATE bodegas SET regimen_tributario = 'NUEVO_RUS';
ALTER TABLE bodegas ALTER COLUMN regimen_tributario SET DEFAULT 'NUEVO_RUS';

-- 2. ROBUSTEZ TELEMÁTICA EN RESPUESTAS DE SUNAT / OSE / PSE
-- Las descripciones de CDR o mensajes de error de excepción SUNAT pueden exceder los 255 caracteres.
-- Convertir sunat_mensaje a TEXT para blindar la base de datos contra errores de longitud.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'ventas' AND column_name = 'sunat_mensaje'
    ) THEN
        ALTER TABLE ventas ALTER COLUMN sunat_mensaje TYPE TEXT;
    ELSE
        ALTER TABLE ventas ADD COLUMN sunat_mensaje TEXT;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'ventas' AND column_name = 'sunat_hash'
    ) THEN
        ALTER TABLE ventas ALTER COLUMN sunat_hash TYPE VARCHAR(255);
    ELSE
        ALTER TABLE ventas ADD COLUMN sunat_hash VARCHAR(255);
    END IF;
END $$;

-- 3. AUDITORÍA FINANCIERA DE CAJA Y ARQUEO DE VUELTO
-- Registra con cuánto pagó el cliente y el vuelto entregado por el cajero (Arqueo y Reconciliación).
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS monto_recibido NUMERIC(12,2);
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS vuelto NUMERIC(12,2);

-- 4. INTEGRIDAD DE CLIENTE ANÓNIMO (CONSUMIDOR FINAL / CLIENTES VARIOS)
-- Asegurar que cliente_documento permita nulos sin restricciones heredadas
ALTER TABLE ventas ALTER COLUMN cliente_documento DROP NOT NULL;
ALTER TABLE ventas ALTER COLUMN cliente_nombre SET DEFAULT 'Clientes Varios';

-- 5. ÍNDICE COMPUESTO PARA RECONCILIACIÓN DE EFECTIVO Y ARQUEO DIARIO
CREATE INDEX IF NOT EXISTS idx_ventas_arqueo_efectivo 
    ON ventas(id_bodega, metodo_pago, fecha_venta DESC) 
    WHERE estado = 'COMPLETADA';

-- 6. ACTUALIZACIÓN DE VISTA DE VENTAS DIARIAS CON AUDITORÍA DE VUELTO
CREATE OR REPLACE VIEW v_ventas_diarias_bodega AS
SELECT 
    v.id_bodega,
    b.nombre_comercial AS bodega,
    DATE(v.fecha_venta AT TIME ZONE 'America/Lima') AS fecha,
    COUNT(*) AS total_transacciones,
    COUNT(*) FILTER (WHERE v.estado = 'COMPLETADA') AS transacciones_exitosas,
    COUNT(*) FILTER (WHERE v.estado = 'ANULADA') AS transacciones_anuladas,
    COALESCE(SUM(v.total) FILTER (WHERE v.estado = 'COMPLETADA'), 0) AS total_recaudado,
    COALESCE(SUM(v.total) FILTER (WHERE v.estado = 'COMPLETADA' AND LOWER(v.metodo_pago) = 'efectivo'), 0) AS total_efectivo,
    COALESCE(SUM(v.vuelto) FILTER (WHERE v.estado = 'COMPLETADA' AND LOWER(v.metodo_pago) = 'efectivo'), 0) AS total_vuelto_entregado,
    COALESCE(SUM(v.total) FILTER (WHERE v.estado = 'COMPLETADA' AND LOWER(v.metodo_pago) = 'yape'), 0) AS total_yape,
    COALESCE(SUM(v.total) FILTER (WHERE v.estado = 'COMPLETADA' AND LOWER(v.metodo_pago) = 'plin'), 0) AS total_plin,
    COALESCE(SUM(v.total) FILTER (WHERE v.estado = 'COMPLETADA' AND (LOWER(v.metodo_pago) LIKE '%tarjeta%' OR LOWER(v.metodo_pago) LIKE '%pos%')), 0) AS total_tarjeta,
    COALESCE(SUM(v.total) FILTER (WHERE v.estado = 'ANULADA'), 0) AS total_anulado
FROM ventas v
JOIN bodegas b ON b.id_bodega = v.id_bodega
GROUP BY v.id_bodega, b.nombre_comercial, DATE(v.fecha_venta AT TIME ZONE 'America/Lima');
