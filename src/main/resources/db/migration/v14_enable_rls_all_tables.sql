-- ==============================================================================
-- MIGRACIÓN V14: ENFORCEMENT UNIVERSAL DE ROW LEVEL SECURITY (RLS)
-- Y CONFIGURACIÓN SECURITY INVOKER EN VISTAS
-- CajaYa Cloud POS Platform - Supabase Security Compliance & Isolation
-- ==============================================================================

-- 1. Habilitación Dinámica de RLS en TODAS las tablas existentes del esquema 'public'
-- Esto previene cualquier acceso público no autorizado a través del endpoint REST de Supabase (PostgREST)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public' 
          AND rowsecurity = false
    ) LOOP
        EXECUTE 'ALTER TABLE public.' || quote_ident(r.tablename) || ' ENABLE ROW LEVEL SECURITY;';
        RAISE NOTICE 'RLS habilitado en tabla: public.%', r.tablename;
    END LOOP;
END $$;

-- 2. Habilitación Explícita de RLS en todas las tablas transaccionales y de soporte
ALTER TABLE IF EXISTS bodegas ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS proveedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS ventas_detalles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS compras ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS compras_detalles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS movimientos_inventario ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS presentaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS abonos_credito ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS fondos_caja ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS egresos_caja ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS pagos_suscripciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS mermas_desmedros ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS auditorias_inventario ENABLE ROW LEVEL SECURITY;

-- 3. Políticas RLS de Aislamiento Estricto Multi-Tenant
-- Se elimina la cláusula permisiva 'app_current_tenant_id() IS NULL' para garantizar que peticiones
-- externas sin variable de inquilino activa sean bloqueadas de forma terminante por el kernel de PostgreSQL.

-- RLS: Clientes
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'clientes') THEN
        DROP POLICY IF EXISTS rls_clientes_tenant ON clientes;
        CREATE POLICY rls_clientes_tenant ON clientes
        FOR ALL USING (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;

-- RLS: Abonos Crédito
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'abonos_credito') THEN
        DROP POLICY IF EXISTS rls_abonos_credito_tenant ON abonos_credito;
        CREATE POLICY rls_abonos_credito_tenant ON abonos_credito
        FOR ALL USING (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;

-- RLS: Fondos Caja
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'fondos_caja') THEN
        DROP POLICY IF EXISTS rls_fondos_caja_tenant ON fondos_caja;
        CREATE POLICY rls_fondos_caja_tenant ON fondos_caja
        FOR ALL USING (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;

-- RLS: Egresos Caja
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'egresos_caja') THEN
        DROP POLICY IF EXISTS rls_egresos_caja_tenant ON egresos_caja;
        CREATE POLICY rls_egresos_caja_tenant ON egresos_caja
        FOR ALL USING (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;

-- RLS: Mermas y Desmedros
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'mermas_desmedros') THEN
        DROP POLICY IF EXISTS rls_mermas_desmedros_tenant ON mermas_desmedros;
        CREATE POLICY rls_mermas_desmedros_tenant ON mermas_desmedros
        FOR ALL USING (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;

-- RLS: Auditorías de Inventario
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'auditorias_inventario') THEN
        DROP POLICY IF EXISTS rls_auditorias_inventario_tenant ON auditorias_inventario;
        CREATE POLICY rls_auditorias_inventario_tenant ON auditorias_inventario
        FOR ALL USING (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;

-- RLS: Pagos Suscripciones
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'pagos_suscripciones') THEN
        DROP POLICY IF EXISTS rls_pagos_suscripciones_tenant ON pagos_suscripciones;
        CREATE POLICY rls_pagos_suscripciones_tenant ON pagos_suscripciones
        FOR ALL USING (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        ) WITH CHECK (
            app_is_superadmin() OR id_bodega = app_current_tenant_id()
        );
    END IF;
END $$;

-- 4. Revocación Total de Privilegios a los Roles Públicos de Supabase (anon y authenticated)
-- Como CajaYa utiliza su propia autenticación JWT en Spring Boot, los roles de PostgREST no deben tener acceso a las tablas
DO $$ BEGIN
    REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
    REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
    REVOKE ALL ON ALL ROUTINES IN SCHEMA public FROM anon, authenticated;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- 5. Configurar SECURITY INVOKER en las Vistas (Corrige error security_definer_view)
-- En PostgreSQL 15+, las vistas deben tener security_invoker = true para que respeten
-- los permisos y RLS de la sesión que las consulta en lugar de los del creador (postgres).
ALTER VIEW IF EXISTS public.v_kardex_general SET (security_invoker = true);
ALTER VIEW IF EXISTS public.v_rendimiento_cajeros SET (security_invoker = true);
ALTER VIEW IF EXISTS public.v_resumen_bodegas SET (security_invoker = true);
ALTER VIEW IF EXISTS public.v_ventas_diarias_bodega SET (security_invoker = true);
ALTER VIEW IF EXISTS public.v_ingresos_plataforma SET (security_invoker = true);
ALTER VIEW IF EXISTS public.v_top_productos_bodega SET (security_invoker = true);
ALTER VIEW IF EXISTS public.v_productos_bajo_stock SET (security_invoker = true);

-- Aplicación dinámica en cualquier otra vista existente en schema public
DO $$
DECLARE
    v RECORD;
BEGIN
    FOR v IN (
        SELECT table_name 
        FROM information_schema.views 
        WHERE table_schema = 'public'
    ) LOOP
        EXECUTE 'ALTER VIEW public.' || quote_ident(v.table_name) || ' SET (security_invoker = true);';
    END LOOP;
END $$;
