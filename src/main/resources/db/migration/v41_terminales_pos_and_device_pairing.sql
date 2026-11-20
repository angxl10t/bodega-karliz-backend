-- ==============================================================================
-- Migración v41: Sistema de Vinculación Segura de Terminales POS (Device Pairing)
-- Reemplaza la enumeración pública de id_bodega por Códigos OTP de un solo uso
-- y Tokens Criptográficos de Hardware (X-Terminal-Token).
-- 100% Idempotente y seguro para producción.
-- ==============================================================================

-- 1. Tabla de Terminales POS Vinculadas
CREATE TABLE IF NOT EXISTS public.terminales_pos (
    id_terminal BIGSERIAL PRIMARY KEY,
    id_bodega BIGINT NOT NULL REFERENCES public.bodegas(id_bodega) ON DELETE CASCADE,
    nombre VARCHAR(100) NOT NULL,
    terminal_token VARCHAR(120) NOT NULL UNIQUE,
    device_model VARCHAR(150),
    fecha_vinculacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ultimo_acceso TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    estado BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_terminales_bodega_estado ON public.terminales_pos(id_bodega, estado);
CREATE INDEX IF NOT EXISTS idx_terminales_token ON public.terminales_pos(terminal_token);

-- 2. Tabla de Códigos de Emparejamiento (Pairing Codes de un solo uso / 10 min TTL)
CREATE TABLE IF NOT EXISTS public.terminal_codigos_pairing (
    id BIGSERIAL PRIMARY KEY,
    id_bodega BIGINT NOT NULL REFERENCES public.bodegas(id_bodega) ON DELETE CASCADE,
    codigo VARCHAR(12) NOT NULL,
    fecha_expiracion TIMESTAMP WITH TIME ZONE NOT NULL,
    usado BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    creado_por_username VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_pairing_codigo_usado ON public.terminal_codigos_pairing(codigo, usado);
CREATE INDEX IF NOT EXISTS idx_pairing_bodega ON public.terminal_codigos_pairing(id_bodega);
