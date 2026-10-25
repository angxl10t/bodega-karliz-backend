-- =========================================================================
-- V12: Control de Inventario Avanzado, Vencimientos y Mermas
-- =========================================================================

-- 1. Soporte de Fecha de Vencimiento y Precio de Costo en Productos
ALTER TABLE productos ADD COLUMN IF NOT EXISTS fecha_vencimiento DATE;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS precio_costo NUMERIC(12,2);
CREATE INDEX IF NOT EXISTS idx_productos_vencimiento ON productos(id_bodega, fecha_vencimiento);

-- 2. Tabla de Registro de Mermas y Desmedros
CREATE TABLE IF NOT EXISTS mermas_desmedros (
    id_merma BIGSERIAL PRIMARY KEY,
    id_bodega BIGINT REFERENCES bodegas(id_bodega),
    id_producto BIGINT REFERENCES productos(id_producto),
    cantidad NUMERIC(12,3) NOT NULL,
    motivo VARCHAR(50) NOT NULL,
    costo_unitario NUMERIC(12,2) NOT NULL,
    costo_total NUMERIC(12,2) NOT NULL,
    observaciones VARCHAR(255),
    usuario_responsable VARCHAR(100),
    fecha TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_mermas_bodega_fecha ON mermas_desmedros(id_bodega, fecha DESC);

-- 3. Tabla de Auditorías de Inventario Físico Ciego
CREATE TABLE IF NOT EXISTS auditorias_inventario (
    id_auditoria BIGSERIAL PRIMARY KEY,
    id_bodega BIGINT REFERENCES bodegas(id_bodega),
    titulo VARCHAR(150) NOT NULL,
    fecha_inicio TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_cierre TIMESTAMP WITH TIME ZONE,
    estado VARCHAR(30) DEFAULT 'ABIERTA',
    total_items_auditados INT DEFAULT 0,
    total_faltantes NUMERIC(12,3) DEFAULT 0,
    total_sobrantes NUMERIC(12,3) DEFAULT 0,
    valor_discrepancia_total NUMERIC(12,2) DEFAULT 0,
    usuario_responsable VARCHAR(100),
    detalles_json TEXT
);
CREATE INDEX IF NOT EXISTS idx_auditorias_bodega_fecha ON auditorias_inventario(id_bodega, fecha_inicio DESC);
