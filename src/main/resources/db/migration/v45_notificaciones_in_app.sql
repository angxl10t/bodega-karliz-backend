-- ==============================================================================
-- MIGRACIÓN V45: SISTEMA DE NOTIFICACIONES IN-APP EN TIEMPO REAL (SSE)
-- CajaYa Cloud POS Platform - Multi-Tenant Security & Role-Based Isolation
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.notificaciones (
    id_notificacion         BIGSERIAL PRIMARY KEY,
    id_bodega               BIGINT NOT NULL REFERENCES public.bodegas(id_bodega) ON DELETE CASCADE,
    id_usuario_destinatario BIGINT REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE,
    rol_destinatario        VARCHAR(30) NOT NULL DEFAULT 'TODOS',
    tipo                    VARCHAR(50) NOT NULL,
    titulo                  VARCHAR(150) NOT NULL,
    mensaje                 TEXT NOT NULL,
    metadata_json           TEXT,
    prioridad               VARCHAR(20) NOT NULL DEFAULT 'MEDIA',
    leido                   BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_creacion          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_leido             TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_notif_bodega_leido 
    ON public.notificaciones(id_bodega, leido, fecha_creacion DESC);

CREATE INDEX IF NOT EXISTS idx_notif_bodega_usuario 
    ON public.notificaciones(id_bodega, id_usuario_destinatario, leido);

CREATE INDEX IF NOT EXISTS idx_notif_bodega_rol 
    ON public.notificaciones(id_bodega, rol_destinatario, leido);

-- Seguridad a nivel de filas (RLS) para aislamiento multi-inquilino estricto
ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'notificaciones') THEN
        DROP POLICY IF EXISTS rls_notificaciones_tenant ON public.notificaciones;
        CREATE POLICY rls_notificaciones_tenant ON public.notificaciones
        FOR ALL USING (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;
