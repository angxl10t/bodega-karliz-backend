-- ==============================================================================
-- MIGRACIÓN V2: REFINAMIENTO DE BASE DE DATOS Y ROW LEVEL SECURITY (RLS)
-- CajaYa Cloud POS Platform - Multi-Tenant Database Architecture
-- ==============================================================================

-- 1. ESTRUCTURACIÓN DE TABLAS HIJAS CON id_bodega DIRECTO (Aislamiento & Rendimiento)
ALTER TABLE movimientos_inventario ADD COLUMN IF NOT EXISTS id_bodega BIGINT REFERENCES bodegas(id_bodega);
ALTER TABLE presentaciones ADD COLUMN IF NOT EXISTS id_bodega BIGINT REFERENCES bodegas(id_bodega);
ALTER TABLE ventas_detalles ADD COLUMN IF NOT EXISTS id_bodega BIGINT REFERENCES bodegas(id_bodega);
ALTER TABLE compras_detalles ADD COLUMN IF NOT EXISTS id_bodega BIGINT REFERENCES bodegas(id_bodega);

-- Retrocompatibilidad y Backfill seguro (Zero Data Loss)
UPDATE movimientos_inventario m 
SET id_bodega = p.id_bodega 
FROM productos p 
WHERE m.id_producto = p.id_producto AND m.id_bodega IS NULL;

UPDATE presentaciones pr 
SET id_bodega = p.id_bodega 
FROM productos p 
WHERE pr.id_producto = p.id_producto AND pr.id_bodega IS NULL;

UPDATE ventas_detalles vd 
SET id_bodega = v.id_bodega 
FROM ventas v 
WHERE vd.id_venta = v.id_venta AND vd.id_bodega IS NULL;

UPDATE compras_detalles cd 
SET id_bodega = c.id_bodega 
FROM compras c 
WHERE cd.id_compra = c.id_compra AND cd.id_bodega IS NULL;

-- 2. REFINAMIENTO DE AUDITORÍA Y TRAZABILIDAD
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE proveedores ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE compras ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 3. ELIMINACIÓN DE RESTRICCIONES GLOBALES Y CONVERSIÓN A TENANT-SCOPED (MULTI-TIENDA)
-- En un SaaS multi-tenant, dos bodegas distintas pueden tener el mismo código de barras o comprar al mismo proveedor RUC.
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Eliminar constraints unicas globales viejas en productos si existen
    FOR r IN (
        SELECT conname FROM pg_constraint 
        WHERE conrelid = 'productos'::regclass AND contype = 'u' 
          AND conname NOT LIKE '%bodega%'
    ) LOOP
        EXECUTE 'ALTER TABLE productos DROP CONSTRAINT IF EXISTS ' || quote_ident(r.conname);
    END LOOP;

    -- Eliminar constraints unicas globales viejas en proveedores si existen
    FOR r IN (
        SELECT conname FROM pg_constraint 
        WHERE conrelid = 'proveedores'::regclass AND contype = 'u' 
          AND conname NOT LIKE '%bodega%'
    ) LOOP
        EXECUTE 'ALTER TABLE proveedores DROP CONSTRAINT IF EXISTS ' || quote_ident(r.conname);
    END LOOP;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- Crear índices únicos seccionados por bodega
CREATE UNIQUE INDEX IF NOT EXISTS uk_productos_bodega_codigo ON productos(id_bodega, codigo) WHERE estado = true;
CREATE UNIQUE INDEX IF NOT EXISTS uk_productos_bodega_codigo_barras ON productos(id_bodega, codigo_barras) WHERE estado = true AND codigo_barras IS NOT NULL AND codigo_barras != '';
CREATE UNIQUE INDEX IF NOT EXISTS uk_proveedores_bodega_ruc ON proveedores(id_bodega, ruc) WHERE estado = true;
CREATE UNIQUE INDEX IF NOT EXISTS uk_categorias_bodega_nombre ON categorias(id_bodega, LOWER(nombre)) WHERE estado = true;

-- 4. ÍNDICES COMPUESTOS DE ALTO RENDIMIENTO (OPTIMIZACIÓN DE CONSULTAS Y REPORTES)
CREATE INDEX IF NOT EXISTS idx_movimientos_bodega_fecha ON movimientos_inventario(id_bodega, fecha_movimiento DESC);
CREATE INDEX IF NOT EXISTS idx_presentaciones_bodega_producto ON presentaciones(id_bodega, id_producto);
CREATE INDEX IF NOT EXISTS idx_ventas_detalles_bodega_venta ON ventas_detalles(id_bodega, id_venta);
CREATE INDEX IF NOT EXISTS idx_compras_detalles_bodega_compra ON compras_detalles(id_bodega, id_compra);
CREATE INDEX IF NOT EXISTS idx_productos_bodega_stock ON productos(id_bodega, stock_actual, stock_minimo);
CREATE INDEX IF NOT EXISTS idx_ventas_bodega_estado_fecha ON ventas(id_bodega, estado, fecha_venta DESC);

-- 5. FUNCIONES HELPER PARA ROW LEVEL SECURITY (RLS)
CREATE OR REPLACE FUNCTION app_current_tenant_id() RETURNS BIGINT AS $$
BEGIN
    RETURN NULLIF(current_setting('app.current_tenant_id', true), '')::BIGINT;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION app_is_superadmin() RETURNS BOOLEAN AS $$
BEGIN
    RETURN current_setting('app.current_tenant_id', true) = 'SUPERADMIN' 
        OR current_setting('app.is_superadmin', true) = 'true';
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql STABLE;

-- 6. HABILITACIÓN DE ROW LEVEL SECURITY (RLS) EN TABLAS CLAVE
ALTER TABLE bodegas ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE proveedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas_detalles ENABLE ROW LEVEL SECURITY;
ALTER TABLE compras ENABLE ROW LEVEL SECURITY;
ALTER TABLE compras_detalles ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimientos_inventario ENABLE ROW LEVEL SECURITY;
ALTER TABLE presentaciones ENABLE ROW LEVEL SECURITY;

-- 7. POLÍTICAS RLS DE AISLAMIENTO ESTRICTO MULTI-TENANT
-- Regla general: Si no se especifica tenant (migraciones/procesos internos) o si es SUPERADMIN, permite todo.
-- Cuando un tenant está activo en la sesión (app.current_tenant_id), PostgreSQL bloquea a nivel kernel cualquier fila de otra bodega.

-- RLS: Bodegas
DROP POLICY IF EXISTS rls_bodegas_tenant ON bodegas;
CREATE POLICY rls_bodegas_tenant ON bodegas
FOR ALL USING (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
) WITH CHECK (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
);

-- RLS: Usuarios
DROP POLICY IF EXISTS rls_usuarios_tenant ON usuarios;
CREATE POLICY rls_usuarios_tenant ON usuarios
FOR ALL USING (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
) WITH CHECK (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
);

-- RLS: Productos
DROP POLICY IF EXISTS rls_productos_tenant ON productos;
CREATE POLICY rls_productos_tenant ON productos
FOR ALL USING (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
) WITH CHECK (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
);

-- RLS: Categorias
DROP POLICY IF EXISTS rls_categorias_tenant ON categorias;
CREATE POLICY rls_categorias_tenant ON categorias
FOR ALL USING (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
) WITH CHECK (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
);

-- RLS: Proveedores
DROP POLICY IF EXISTS rls_proveedores_tenant ON proveedores;
CREATE POLICY rls_proveedores_tenant ON proveedores
FOR ALL USING (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
) WITH CHECK (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
);

-- RLS: Ventas
DROP POLICY IF EXISTS rls_ventas_tenant ON ventas;
CREATE POLICY rls_ventas_tenant ON ventas
FOR ALL USING (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
) WITH CHECK (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
);

-- RLS: Ventas Detalles
DROP POLICY IF EXISTS rls_ventas_detalles_tenant ON ventas_detalles;
CREATE POLICY rls_ventas_detalles_tenant ON ventas_detalles
FOR ALL USING (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
) WITH CHECK (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
);

-- RLS: Compras
DROP POLICY IF EXISTS rls_compras_tenant ON compras;
CREATE POLICY rls_compras_tenant ON compras
FOR ALL USING (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
) WITH CHECK (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
);

-- RLS: Compras Detalles
DROP POLICY IF EXISTS rls_compras_detalles_tenant ON compras_detalles;
CREATE POLICY rls_compras_detalles_tenant ON compras_detalles
FOR ALL USING (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
) WITH CHECK (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
);

-- RLS: Movimientos de Inventario (Kardex)
DROP POLICY IF EXISTS rls_movimientos_tenant ON movimientos_inventario;
CREATE POLICY rls_movimientos_tenant ON movimientos_inventario
FOR ALL USING (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
) WITH CHECK (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
);

-- RLS: Presentaciones
DROP POLICY IF EXISTS rls_presentaciones_tenant ON presentaciones;
CREATE POLICY rls_presentaciones_tenant ON presentaciones
FOR ALL USING (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
) WITH CHECK (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
);

-- 8. VISTAS DE ADMINISTRACIÓN Y ANALÍTICA (DBA & MANAGEMENT EXPERIENCE)
CREATE OR REPLACE VIEW v_resumen_bodegas AS
SELECT 
    b.id_bodega,
    b.nombre_comercial,
    b.ruc_dni,
    b.plan,
    b.estado,
    b.fecha_registro,
    b.fecha_vencimiento_plan,
    b.facturacion_sunat_activa,
    COUNT(DISTINCT u.id_usuario) FILTER (WHERE u.estado = TRUE) AS total_usuarios_activos,
    COUNT(DISTINCT p.id_producto) FILTER (WHERE p.estado = TRUE) AS total_productos_activos,
    COUNT(DISTINCT v.id_venta) FILTER (WHERE v.estado = 'COMPLETADA') AS total_ventas_historicas,
    COALESCE(SUM(v.total) FILTER (WHERE v.estado = 'COMPLETADA'), 0) AS total_ingresos_historicos
FROM bodegas b
LEFT JOIN usuarios u ON u.id_bodega = b.id_bodega
LEFT JOIN productos p ON p.id_bodega = b.id_bodega
LEFT JOIN ventas v ON v.id_bodega = b.id_bodega
GROUP BY b.id_bodega, b.nombre_comercial, b.ruc_dni, b.plan, b.estado, b.fecha_registro, b.fecha_vencimiento_plan, b.facturacion_sunat_activa;

CREATE OR REPLACE VIEW v_kardex_general AS
SELECT 
    m.id_movimiento,
    m.id_bodega,
    b.nombre_comercial AS bodega,
    p.id_producto,
    p.codigo,
    p.codigo_barras,
    p.nombre AS producto,
    m.tipo_movimiento,
    m.cantidad,
    m.motivo,
    m.usuario_responsable,
    m.fecha_movimiento
FROM movimientos_inventario m
LEFT JOIN productos p ON p.id_producto = m.id_producto
LEFT JOIN bodegas b ON b.id_bodega = m.id_bodega;
