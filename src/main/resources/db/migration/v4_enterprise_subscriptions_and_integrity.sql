-- ==============================================================================
-- MIGRACIÓN V4: LIBRO MAYOR DE SUSCRIPCIONES, INTEGRIDAD FINANCIERA E ÍNDICES DE ESCALABILIDAD
-- CajaYa Cloud POS Platform - Multi-Tenant Enterprise Architecture
-- ==============================================================================

-- 1. TABLA DE PAGOS DE SUSCRIPCIONES (LEDGER FISCAL & PREVENCIÓN DE VOUCHERS DUPLICADOS)
CREATE TABLE IF NOT EXISTS pagos_suscripciones (
    id_pago BIGSERIAL PRIMARY KEY,
    id_bodega BIGINT NOT NULL REFERENCES bodegas(id_bodega),
    codigo_operacion VARCHAR(50) NOT NULL,
    billetera VARCHAR(30) NOT NULL,
    plan VARCHAR(30) NOT NULL,
    monto NUMERIC(12,2) NOT NULL,
    fecha_pago TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    usuario_registro VARCHAR(50),
    estado VARCHAR(30) NOT NULL DEFAULT 'CONFIRMADO',
    CONSTRAINT uk_pagos_billetera_operacion UNIQUE (billetera, codigo_operacion)
);

-- 2. ROW LEVEL SECURITY (RLS) EN PAGOS DE SUSCRIPCIONES
ALTER TABLE pagos_suscripciones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_pagos_suscripciones_tenant ON pagos_suscripciones;
CREATE POLICY rls_pagos_suscripciones_tenant ON pagos_suscripciones
FOR ALL USING (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
) WITH CHECK (
    app_is_superadmin() OR app_current_tenant_id() IS NULL OR id_bodega = app_current_tenant_id()
);

-- 3. ÍNDICES DE ALTO RENDIMIENTO EN PAGOS DE SUSCRIPCIONES
CREATE INDEX IF NOT EXISTS idx_pagos_bodega_fecha ON pagos_suscripciones(id_bodega, fecha_pago DESC);
CREATE INDEX IF NOT EXISTS idx_pagos_fecha ON pagos_suscripciones(fecha_pago DESC);

-- 4. ÍNDICES DE CLAVES FORÁNEAS FALTANTES PARA OPTIMIZAR JOINS Y AGREGACIONES
CREATE INDEX IF NOT EXISTS idx_productos_categoria ON productos(id_categoria);
CREATE INDEX IF NOT EXISTS idx_productos_bodega_categoria ON productos(id_bodega, id_categoria, estado);
CREATE INDEX IF NOT EXISTS idx_presentaciones_producto ON presentaciones(id_producto);
CREATE INDEX IF NOT EXISTS idx_ventas_detalles_producto ON ventas_detalles(id_producto);
CREATE INDEX IF NOT EXISTS idx_ventas_detalles_bodega_producto ON ventas_detalles(id_bodega, id_producto);
CREATE INDEX IF NOT EXISTS idx_compras_detalles_producto ON compras_detalles(id_producto);
CREATE INDEX IF NOT EXISTS idx_compras_detalles_bodega_producto ON compras_detalles(id_bodega, id_producto);
CREATE INDEX IF NOT EXISTS idx_compras_bodega_proveedor ON compras(id_bodega, id_proveedor);

-- 5. ÍNDICES PARCIALES Y COMPUESTOS PARA DASHBOARDS Y REPORTES EN TIEMPO REAL
CREATE INDEX IF NOT EXISTS idx_ventas_bodega_completadas ON ventas(id_bodega, fecha_venta DESC) WHERE estado = 'COMPLETADA';
CREATE INDEX IF NOT EXISTS idx_ventas_bodega_cliente ON ventas(id_bodega, cliente_documento) WHERE cliente_documento IS NOT NULL AND cliente_documento != '';
CREATE INDEX IF NOT EXISTS idx_ventas_bodega_usuario ON ventas(id_bodega, usuario_registro, fecha_venta DESC);
CREATE INDEX IF NOT EXISTS idx_ventas_bodega_metodo ON ventas(id_bodega, metodo_pago, fecha_venta DESC);
CREATE INDEX IF NOT EXISTS idx_productos_bajo_stock_alert ON productos(id_bodega, stock_actual, stock_minimo) WHERE estado = TRUE AND stock_actual <= stock_minimo;

-- 6. UNICIDAD CASE-INSENSITIVE PARA USERNAMES
CREATE UNIQUE INDEX IF NOT EXISTS uk_usuarios_lower_username ON usuarios(LOWER(username));

-- 7. OPTIMIZACIÓN HEAP-ONLY TUPLES (HOT) EN BODEGAS
-- Previene fragmentación y reescritura de índices por actualización constante de correlativos
ALTER TABLE bodegas SET (fillfactor = 90);

-- 8. RESTRICCIONES CHECK DE INTEGRIDAD MATEMÁTICA Y FINANCIERA (DEFENSA EN PROFUNDIDAD)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_productos_precio_positivo') THEN
        ALTER TABLE productos ADD CONSTRAINT ck_productos_precio_positivo CHECK (precio_venta >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_productos_stock_minimo_positivo') THEN
        ALTER TABLE productos ADD CONSTRAINT ck_productos_stock_minimo_positivo CHECK (stock_minimo >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_ventas_total_positivo') THEN
        ALTER TABLE ventas ADD CONSTRAINT ck_ventas_total_positivo CHECK (total >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_ventas_detalles_cantidad_positiva') THEN
        ALTER TABLE ventas_detalles ADD CONSTRAINT ck_ventas_detalles_cantidad_positiva CHECK (cantidad > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_ventas_detalles_precio_positivo') THEN
        ALTER TABLE ventas_detalles ADD CONSTRAINT ck_ventas_detalles_precio_positivo CHECK (precio_unitario >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_compras_total_positivo') THEN
        ALTER TABLE compras ADD CONSTRAINT ck_compras_total_positivo CHECK (total >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_compras_detalles_cantidad_positiva') THEN
        ALTER TABLE compras_detalles ADD CONSTRAINT ck_compras_detalles_cantidad_positiva CHECK (cantidad > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_compras_detalles_precio_positivo') THEN
        ALTER TABLE compras_detalles ADD CONSTRAINT ck_compras_detalles_precio_positivo CHECK (precio_unitario >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_pagos_monto_positivo') THEN
        ALTER TABLE pagos_suscripciones ADD CONSTRAINT ck_pagos_monto_positivo CHECK (monto > 0);
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- 9. ATRIBUTO DE NOMBRE COMPLETO EN USUARIOS (MEJORA UI/UX Y TICKETS)
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS nombre_completo VARCHAR(150);

-- 10. VISTAS ANALÍTICAS Y DE GESTIÓN (BUSINESS INTELLIGENCE & PLATFORM OBSERVABILITY)

-- 10.1 Vista de Ingresos de Plataforma SaaS para SuperAdmin
CREATE OR REPLACE VIEW v_ingresos_plataforma AS
SELECT 
    DATE_TRUNC('month', fecha_pago AT TIME ZONE 'America/Lima') AS mes,
    plan,
    billetera,
    COUNT(*) AS total_renovaciones,
    SUM(monto) AS total_recaudado
FROM pagos_suscripciones
WHERE estado = 'CONFIRMADO'
GROUP BY DATE_TRUNC('month', fecha_pago AT TIME ZONE 'America/Lima'), plan, billetera;

-- 10.2 Vista de Top Productos más Vendidos por Bodega (Últimos 30 días)
CREATE OR REPLACE VIEW v_top_productos_bodega AS
SELECT 
    vd.id_bodega,
    b.nombre_comercial AS bodega,
    p.id_producto,
    p.codigo,
    p.nombre AS producto,
    p.marca,
    c.nombre AS categoria,
    SUM(vd.cantidad) AS unidades_vendidas,
    SUM(vd.subtotal) AS total_recaudado,
    COUNT(DISTINCT vd.id_venta) AS total_transacciones
FROM ventas_detalles vd
JOIN ventas v ON v.id_venta = vd.id_venta
JOIN productos p ON p.id_producto = vd.id_producto
JOIN bodegas b ON b.id_bodega = vd.id_bodega
LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
WHERE v.estado = 'COMPLETADA'
  AND v.fecha_venta >= (NOW() - INTERVAL '30 days')
GROUP BY vd.id_bodega, b.nombre_comercial, p.id_producto, p.codigo, p.nombre, p.marca, c.nombre;

-- 10.3 Vista de Rendimiento por Cajero y Turno
CREATE OR REPLACE VIEW v_rendimiento_cajeros AS
SELECT 
    v.id_bodega,
    b.nombre_comercial AS bodega,
    COALESCE(u.nombre_completo, v.usuario_registro) AS cajero,
    DATE(v.fecha_venta AT TIME ZONE 'America/Lima') AS fecha,
    COUNT(*) FILTER (WHERE v.estado = 'COMPLETADA') AS ventas_completadas,
    COALESCE(SUM(v.total) FILTER (WHERE v.estado = 'COMPLETADA'), 0) AS total_recaudado,
    COUNT(*) FILTER (WHERE v.estado = 'ANULADA') AS ventas_anuladas,
    COALESCE(SUM(v.total) FILTER (WHERE v.estado = 'ANULADA'), 0) AS total_anulado
FROM ventas v
JOIN bodegas b ON b.id_bodega = v.id_bodega
LEFT JOIN usuarios u ON LOWER(u.username) = LOWER(v.usuario_registro) AND u.id_bodega = v.id_bodega
GROUP BY v.id_bodega, b.nombre_comercial, COALESCE(u.nombre_completo, v.usuario_registro), DATE(v.fecha_venta AT TIME ZONE 'America/Lima');
