-- ==============================================================================
-- MIGRACIÓN V24: REGISTRO DE BOLETAS CONSOLIDADAS DIARIAS (NUEVO RUS - VENTAS <= S/ 5.00)
-- Conforme a la Res. de Superintendencia N° 007-99/SUNAT (Art. 8, Numeral 3.2)
-- y Ley del Bodeguero N° 30877.
-- CajaYa Cloud POS Platform - Multi-Tenant Security & Isolation
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.boletas_consolidadas (
    id_boleta_consolidada BIGSERIAL PRIMARY KEY,
    id_bodega BIGINT NOT NULL REFERENCES public.bodegas(id_bodega) ON DELETE CASCADE,
    fecha_emision DATE NOT NULL,
    monto_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    cantidad_operaciones INTEGER NOT NULL DEFAULT 1,
    serie_correlativo VARCHAR(30) NOT NULL,
    tipo_emision VARCHAR(30) NOT NULL DEFAULT 'TALONARIO_FISICO',
    observaciones VARCHAR(255),
    usuario_registro VARCHAR(50),
    fecha_registro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_boletas_consolidadas_bodega_fecha ON public.boletas_consolidadas(id_bodega, fecha_emision DESC);
CREATE INDEX IF NOT EXISTS idx_boletas_consolidadas_bodega_serie ON public.boletas_consolidadas(id_bodega, serie_correlativo);

ALTER TABLE public.boletas_consolidadas ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'boletas_consolidadas') THEN
        DROP POLICY IF EXISTS rls_boletas_consolidadas_tenant ON public.boletas_consolidadas;
        CREATE POLICY rls_boletas_consolidadas_tenant ON public.boletas_consolidadas
        FOR ALL USING (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;
