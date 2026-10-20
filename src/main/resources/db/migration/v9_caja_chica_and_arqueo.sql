-- ==============================================================================
-- MIGRACIÓN V9: CAJA CHICA, FONDOS INICIALES Y ARQUEO DE TURNO
-- CajaYa Cloud POS Platform - Control de Efectivo y Trazabilidad de Egresos Menores
-- ==============================================================================

CREATE TABLE IF NOT EXISTS fondos_caja (
    id_fondo_caja BIGSERIAL PRIMARY KEY,
    id_bodega BIGINT NOT NULL REFERENCES bodegas(id_bodega),
    fecha DATE NOT NULL,
    monto_inicial NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    usuario_registro VARCHAR(50),
    fecha_registro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_fondos_caja_bodega_fecha UNIQUE (id_bodega, fecha)
);

CREATE INDEX IF NOT EXISTS idx_fondos_caja_bodega_fecha 
    ON fondos_caja(id_bodega, fecha);

CREATE TABLE IF NOT EXISTS egresos_caja (
    id_egreso BIGSERIAL PRIMARY KEY,
    id_bodega BIGINT NOT NULL REFERENCES bodegas(id_bodega),
    monto NUMERIC(12, 2) NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    categoria_gasto VARCHAR(50) DEFAULT 'VARIOS',
    fecha_egreso TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    usuario_registro VARCHAR(50),
    estado BOOLEAN NOT NULL DEFAULT TRUE,
    usuario_anulacion VARCHAR(50),
    motivo_anulacion VARCHAR(255),
    fecha_anulacion TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_egresos_caja_bodega_fecha 
    ON egresos_caja(id_bodega, fecha_egreso DESC);

CREATE INDEX IF NOT EXISTS idx_egresos_caja_bodega_estado 
    ON egresos_caja(id_bodega, estado);
