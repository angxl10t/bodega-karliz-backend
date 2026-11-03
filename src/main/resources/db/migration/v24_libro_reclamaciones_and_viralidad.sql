-- ==============================================================================
-- MIGRACIÓN V24: LIBRO DE RECLAMACIONES VIRTUAL (INDECOPI) Y VIRALIDAD DE BARRIO
-- CajaYa Cloud POS Platform - Cumplimiento Normativo Ley N° 29571 & Ley N° 29733
-- ==============================================================================

-- 1. Tabla de Reclamaciones (Libro de Reclamaciones Virtual Conforme a INDECOPI)
CREATE TABLE IF NOT EXISTS public.reclamaciones (
    id_reclamacion BIGSERIAL PRIMARY KEY,
    codigo_reclamacion VARCHAR(50) NOT NULL UNIQUE,
    id_bodega BIGINT REFERENCES public.bodegas(id_bodega) ON DELETE SET NULL,
    nombre_reclamante VARCHAR(150) NOT NULL,
    tipo_documento VARCHAR(20) NOT NULL, -- 'DNI', 'CE', 'PASAPORTE', 'RUC'
    numero_documento VARCHAR(30) NOT NULL,
    telefono VARCHAR(50),
    email VARCHAR(150) NOT NULL,
    direccion VARCHAR(250),
    tipo VARCHAR(20) NOT NULL DEFAULT 'RECLAMO', -- 'RECLAMO' (bien/servicio) o 'QUEJA' (atención)
    tipo_bien VARCHAR(20) NOT NULL DEFAULT 'PRODUCTO', -- 'PRODUCTO' o 'SERVICIO'
    monto_reclamado NUMERIC(12, 2) DEFAULT 0.00,
    descripcion_bien TEXT,
    detalle_reclamacion TEXT NOT NULL,
    pedido_reclamante TEXT NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE', -- 'PENDIENTE', 'EN_PROCESO', 'ATENDIDO'
    respuesta_proveedor TEXT,
    fecha_reclamo TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_respuesta TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_reclamaciones_codigo ON public.reclamaciones(codigo_reclamacion);
CREATE INDEX IF NOT EXISTS idx_reclamaciones_bodega ON public.reclamaciones(id_bodega);
CREATE INDEX IF NOT EXISTS idx_reclamaciones_estado ON public.reclamaciones(estado);
CREATE INDEX IF NOT EXISTS idx_reclamaciones_fecha ON public.reclamaciones(fecha_reclamo DESC);

ALTER TABLE public.reclamaciones ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'reclamaciones') THEN
        DROP POLICY IF EXISTS rls_reclamaciones_tenant ON public.reclamaciones;
        CREATE POLICY rls_reclamaciones_tenant ON public.reclamaciones
        FOR ALL USING (
            app_is_superadmin() OR id_bodega IS NULL OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega IS NULL OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;

-- 2. Secuencia para correlativo anual de reclamaciones
CREATE SEQUENCE IF NOT EXISTS seq_reclamaciones_correlativo START WITH 1 INCREMENT BY 1;
