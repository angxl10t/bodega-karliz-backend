-- ==============================================================================
-- MIGRACIÓN V22: BANDEJA DE PEDIDOS WEB CLOUD Y SINCRONIZACIÓN POS
-- CajaYa Cloud POS Platform - Multi-Tenant Security & Isolation
-- ==============================================================================

-- 1. Tabla de Pedidos Web
CREATE TABLE IF NOT EXISTS public.pedidos_web (
    id_pedido_web BIGSERIAL PRIMARY KEY,
    id_bodega BIGINT NOT NULL REFERENCES public.bodegas(id_bodega) ON DELETE CASCADE,
    codigo_pedido VARCHAR(50) NOT NULL,
    nombre_cliente VARCHAR(150) NOT NULL,
    telefono_cliente VARCHAR(50),
    notas TEXT,
    total NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ahorro_promociones NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    incluye_retornables BOOLEAN NOT NULL DEFAULT FALSE,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_pedidos_web_bodega_estado ON public.pedidos_web(id_bodega, estado);
CREATE INDEX IF NOT EXISTS idx_pedidos_web_bodega_fecha ON public.pedidos_web(id_bodega, fecha_creacion DESC);
CREATE INDEX IF NOT EXISTS idx_pedidos_web_bodega_codigo ON public.pedidos_web(id_bodega, codigo_pedido);

ALTER TABLE public.pedidos_web ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'pedidos_web') THEN
        DROP POLICY IF EXISTS rls_pedidos_web_tenant ON public.pedidos_web;
        CREATE POLICY rls_pedidos_web_tenant ON public.pedidos_web
        FOR ALL USING (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;

-- 2. Tabla de Detalles de Pedidos Web
CREATE TABLE IF NOT EXISTS public.pedidos_web_detalles (
    id_detalle_pedido_web BIGSERIAL PRIMARY KEY,
    id_pedido_web BIGINT NOT NULL REFERENCES public.pedidos_web(id_pedido_web) ON DELETE CASCADE,
    id_bodega BIGINT NOT NULL REFERENCES public.bodegas(id_bodega) ON DELETE CASCADE,
    id_producto BIGINT REFERENCES public.productos(id_producto) ON DELETE SET NULL,
    nombre_producto VARCHAR(200) NOT NULL,
    cantidad NUMERIC(12, 3) NOT NULL DEFAULT 1.0,
    precio_unitario NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    badge VARCHAR(50)
);

CREATE INDEX IF NOT EXISTS idx_pedidos_web_detalles_pedido ON public.pedidos_web_detalles(id_pedido_web);
CREATE INDEX IF NOT EXISTS idx_pedidos_web_detalles_bodega ON public.pedidos_web_detalles(id_bodega);

ALTER TABLE public.pedidos_web_detalles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'pedidos_web_detalles') THEN
        DROP POLICY IF EXISTS rls_pedidos_web_detalles_tenant ON public.pedidos_web_detalles;
        CREATE POLICY rls_pedidos_web_detalles_tenant ON public.pedidos_web_detalles
        FOR ALL USING (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;
