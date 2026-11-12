-- ==============================================================================
-- MIGRACIÓN V28: PRESET GLOBAL DEL STARTER PACK PARA EL SUPERADMIN
-- Permite al SuperAdmin gestionar y personalizar el catálogo inicial
-- que se clona a cualquier nueva bodega que se registre o provisione.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS catalogo_starter_pack_global (
    id_preset BIGSERIAL PRIMARY KEY,
    codigo_barras VARCHAR(50) NOT NULL UNIQUE,
    nombre VARCHAR(255) NOT NULL,
    marca VARCHAR(100),
    categoria VARCHAR(100) NOT NULL,
    precio_venta NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    precio_costo NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    imagen_url VARCHAR(500),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    fecha_modificacion TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_starter_pack_activo_cat 
    ON catalogo_starter_pack_global(activo, categoria);

CREATE INDEX IF NOT EXISTS idx_starter_pack_barras 
    ON catalogo_starter_pack_global(codigo_barras);
