-- =========================================================================
-- MIGRACIÓN V29: SUGERENCIAS DE PRECIOS Y CATÁLOGO DEL SUPERADMIN A BODEGAS
-- Permite al SuperAdmin sugerir actualizaciones de precios de venta/costo,
-- nombres y marcas a las bodegas sin sobreescribir forzosamente sus datos.
-- Cada bodega decide autónomamente aceptar o rechazar la propuesta.
-- =========================================================================

CREATE TABLE IF NOT EXISTS sugerencias_precio_superadmin (
    id_sugerencia BIGSERIAL PRIMARY KEY,
    id_bodega BIGINT NOT NULL REFERENCES bodegas(id_bodega) ON DELETE CASCADE,
    id_producto BIGINT NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
    codigo_barras VARCHAR(100) NOT NULL,
    nombre_actual VARCHAR(150) NOT NULL,
    nombre_sugerido VARCHAR(150),
    marca_actual VARCHAR(100),
    marca_sugerida VARCHAR(100),
    precio_venta_actual NUMERIC(12, 2) NOT NULL,
    precio_venta_sugerido NUMERIC(12, 2) NOT NULL,
    precio_costo_actual NUMERIC(12, 2),
    precio_costo_sugerido NUMERIC(12, 2),
    motivo VARCHAR(500),
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_resolucion TIMESTAMP WITH TIME ZONE,
    usuario_resolucion VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_sug_bodega_estado ON sugerencias_precio_superadmin(id_bodega, estado);
CREATE INDEX IF NOT EXISTS idx_sug_codigo_barras ON sugerencias_precio_superadmin(codigo_barras);
