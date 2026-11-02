-- ==============================================================================
-- MIGRACIÓN V20: GESTIÓN DE GARANTÍAS DE BOTELLAS DE VIDRIO Y ENVASES RETORNABLES
-- CajaYa Cloud POS - Módulo de Fiados y Garantías de Envases
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.garantias_botellas (
    id_garantia BIGSERIAL PRIMARY KEY,
    id_bodega BIGINT NOT NULL REFERENCES public.bodegas(id_bodega) ON DELETE CASCADE,
    id_cliente BIGINT REFERENCES public.clientes(id_cliente) ON DELETE SET NULL,
    nombre_persona VARCHAR(150) NOT NULL,
    telefono VARCHAR(30),
    cantidad_botellas INTEGER NOT NULL DEFAULT 1,
    monto_garantia NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    tipo_botella VARCHAR(100),
    notas VARCHAR(255),
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    botellas_devueltas INTEGER NOT NULL DEFAULT 0,
    monto_devuelto NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    fecha_registro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_devolucion TIMESTAMP WITH TIME ZONE,
    usuario_registro VARCHAR(50)
);

CREATE INDEX IF NOT EXISTS idx_garantias_botellas_bodega_fecha ON public.garantias_botellas(id_bodega, fecha_registro DESC);
CREATE INDEX IF NOT EXISTS idx_garantias_botellas_bodega_estado ON public.garantias_botellas(id_bodega, estado);
CREATE INDEX IF NOT EXISTS idx_garantias_botellas_cliente ON public.garantias_botellas(id_bodega, id_cliente);

ALTER TABLE public.garantias_botellas ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'garantias_botellas') THEN
        DROP POLICY IF EXISTS rls_garantias_botellas_tenant ON public.garantias_botellas;
        CREATE POLICY rls_garantias_botellas_tenant ON public.garantias_botellas
        FOR ALL USING (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;
