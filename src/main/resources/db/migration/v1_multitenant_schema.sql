-- ==============================================================================
-- MIGRACIÓN MULTI-TENANT: BODEGA POS & CLOUD SAAS
-- Objetivo: Soportar múltiples bodegas independientes sin pérdida de datos históricos.
-- La tienda pionera existente queda asignada automáticamente a id_bodega = 1 (Plan PRO).
-- ==============================================================================

-- 1. Tabla de Bodegas (Tenants)
CREATE TABLE IF NOT EXISTS bodegas (
    id_bodega BIGSERIAL PRIMARY KEY,
    nombre_comercial VARCHAR(150) NOT NULL,
    ruc_dni VARCHAR(20),
    direccion VARCHAR(255),
    telefono VARCHAR(30),
    logo_url VARCHAR(500),
    color_primario VARCHAR(20) DEFAULT '#2563EB',
    lema_comercial VARCHAR(255),
    plan VARCHAR(30) NOT NULL DEFAULT 'BASICO',
    estado BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    fecha_vencimiento_plan TIMESTAMP WITH TIME ZONE
);

-- Asegurar columnas si la tabla ya existía previamente
ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS color_primario VARCHAR(20) DEFAULT '#2563EB';
ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS lema_comercial VARCHAR(255);
UPDATE bodegas SET color_primario = '#2563EB' WHERE color_primario IS NULL;

-- 2. Asegurar que Bodega KARLIZ exista con id_bodega = 1 y Plan PRO
INSERT INTO bodegas (id_bodega, nombre_comercial, ruc_dni, direccion, telefono, plan, color_primario, lema_comercial, estado)
VALUES (1, 'Bodega KARLIZ', '10712345678', 'Av. Principal 123', '987654321', 'PRO', '#2563EB', 'Atención cálida, rápida y surtido completo', TRUE)
ON CONFLICT (id_bodega) DO NOTHING;

-- Ajustar la secuencia si es necesario
SELECT setval(pg_get_serial_sequence('bodegas', 'id_bodega'), COALESCE(MAX(id_bodega), 1)) FROM bodegas;

-- 3. Vincular columna id_bodega en todas las tablas transaccionales
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS id_bodega BIGINT REFERENCES bodegas(id_bodega);
ALTER TABLE productos ADD COLUMN IF NOT EXISTS id_bodega BIGINT REFERENCES bodegas(id_bodega);
ALTER TABLE categorias ADD COLUMN IF NOT EXISTS id_bodega BIGINT REFERENCES bodegas(id_bodega);
ALTER TABLE proveedores ADD COLUMN IF NOT EXISTS id_bodega BIGINT REFERENCES bodegas(id_bodega);
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS id_bodega BIGINT REFERENCES bodegas(id_bodega);
ALTER TABLE compras ADD COLUMN IF NOT EXISTS id_bodega BIGINT REFERENCES bodegas(id_bodega);

-- 4. Asignación retroactiva de todos los datos existentes a la Bodega #1 (Zero Data Loss)
UPDATE usuarios SET id_bodega = 1 WHERE id_bodega IS NULL;
UPDATE productos SET id_bodega = 1 WHERE id_bodega IS NULL;
UPDATE categorias SET id_bodega = 1 WHERE id_bodega IS NULL;
UPDATE proveedores SET id_bodega = 1 WHERE id_bodega IS NULL;
UPDATE ventas SET id_bodega = 1 WHERE id_bodega IS NULL;
UPDATE compras SET id_bodega = 1 WHERE id_bodega IS NULL;

-- 5. Creación de índices compuestos para consultas ultrarrápidas aisladas por bodega
CREATE INDEX IF NOT EXISTS idx_usuarios_bodega ON usuarios(id_bodega, estado);
CREATE INDEX IF NOT EXISTS idx_productos_bodega ON productos(id_bodega, estado);
CREATE INDEX IF NOT EXISTS idx_categorias_bodega ON categorias(id_bodega, estado);
CREATE INDEX IF NOT EXISTS idx_proveedores_bodega ON proveedores(id_bodega, estado);
CREATE INDEX IF NOT EXISTS idx_ventas_bodega_fecha ON ventas(id_bodega, fecha_venta DESC);
CREATE INDEX IF NOT EXISTS idx_compras_bodega_fecha ON compras(id_bodega, fecha_compra DESC);
