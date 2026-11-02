-- ==============================================================================
-- MIGRACIÓN V21: TABLAS DE PROMOCIONES, COMBOS Y TRANSACCIONES BILLETERAS CON RLS
-- CajaYa Cloud POS Platform - Multi-Tenant Security & Isolation
-- ==============================================================================

-- 1. Tabla de Promociones y Descuentos Estratégicos
CREATE TABLE IF NOT EXISTS public.promociones (
    id_promocion BIGSERIAL PRIMARY KEY,
    id_bodega BIGINT NOT NULL REFERENCES public.bodegas(id_bodega) ON DELETE CASCADE,
    titulo VARCHAR(150) NOT NULL,
    descripcion VARCHAR(255),
    tipo_promocion VARCHAR(40) NOT NULL,
    alcance VARCHAR(40) NOT NULL,
    valor_descuento NUMERIC(10, 2),
    id_producto_principal BIGINT REFERENCES public.productos(id_producto) ON DELETE SET NULL,
    id_producto_secundario BIGINT REFERENCES public.productos(id_producto) ON DELETE SET NULL,
    categoria_objetivo VARCHAR(100),
    marca_objetivo VARCHAR(100),
    precio_combo NUMERIC(10, 2),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_inicio DATE,
    fecha_fin DATE,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_promociones_bodega_activo ON public.promociones(id_bodega, activo);
CREATE INDEX IF NOT EXISTS idx_promociones_alcance ON public.promociones(id_bodega, alcance);
CREATE INDEX IF NOT EXISTS idx_promociones_producto_principal ON public.promociones(id_bodega, id_producto_principal);

ALTER TABLE public.promociones ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'promociones') THEN
        DROP POLICY IF EXISTS rls_promociones_tenant ON public.promociones;
        CREATE POLICY rls_promociones_tenant ON public.promociones
        FOR ALL USING (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;

-- 2. Tabla de Transacciones Yape / Plin Recibidas
CREATE TABLE IF NOT EXISTS public.yape_transacciones_recibidas (
    id_transaccion BIGSERIAL PRIMARY KEY,
    codigo_operacion VARCHAR(50) NOT NULL,
    monto NUMERIC(12, 2) NOT NULL,
    billetera VARCHAR(30) NOT NULL DEFAULT 'YAPE',
    nombre_remitente VARCHAR(120),
    texto_notificacion VARCHAR(1000),
    fecha_recepcion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    usado BOOLEAN NOT NULL DEFAULT FALSE,
    id_bodega_asignada BIGINT REFERENCES public.bodegas(id_bodega) ON DELETE SET NULL,
    fecha_uso TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_yape_tx_cod_op ON public.yape_transacciones_recibidas(codigo_operacion);
CREATE INDEX IF NOT EXISTS idx_yape_tx_usado ON public.yape_transacciones_recibidas(usado);
CREATE INDEX IF NOT EXISTS idx_yape_tx_fecha ON public.yape_transacciones_recibidas(fecha_recepcion DESC);
CREATE INDEX IF NOT EXISTS idx_yape_tx_bodega ON public.yape_transacciones_recibidas(id_bodega_asignada);

ALTER TABLE public.yape_transacciones_recibidas ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'yape_transacciones_recibidas') THEN
        DROP POLICY IF EXISTS rls_yape_tx_tenant ON public.yape_transacciones_recibidas;
        CREATE POLICY rls_yape_tx_tenant ON public.yape_transacciones_recibidas
        FOR ALL USING (
            app_is_superadmin() OR id_bodega_asignada IS NULL OR id_bodega_asignada = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega_asignada IS NULL OR id_bodega_asignada = app_current_tenant_id()
        );
    END IF;
END $$;
