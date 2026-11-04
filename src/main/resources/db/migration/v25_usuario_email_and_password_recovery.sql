-- ============================================================================
-- MIGRACIÓN v25: Campo de Correo Electrónico y Sistema de Recuperación de Clave
-- ============================================================================

-- 1. Añadir columna 'email' en tabla usuarios para notificaciones y recuperación
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS email VARCHAR(150);

-- Índice para búsquedas rápidas por email insensible a mayúsculas
CREATE INDEX IF NOT EXISTS idx_usuarios_email_lower ON usuarios(LOWER(email));

-- 2. Tabla para tokens de recuperación de contraseña (códigos OTP temporales de 6 dígitos)
CREATE TABLE IF NOT EXISTS recuperacion_clave (
    id BIGSERIAL PRIMARY KEY,
    id_usuario BIGINT NOT NULL,
    codigo_hash VARCHAR(64) NOT NULL,
    email_destino VARCHAR(150) NOT NULL,
    expiracion TIMESTAMP WITH TIME ZONE NOT NULL,
    usado BOOLEAN NOT NULL DEFAULT FALSE,
    intentos_fallidos INT NOT NULL DEFAULT 0,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_recuperacion_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
);

-- Índice compuesto para validación instantánea de códigos activos no usados
CREATE INDEX IF NOT EXISTS idx_recuperacion_usuario_activo 
ON recuperacion_clave(id_usuario, usado, expiracion);

-- Índice para control de tasa y limpieza periódica por fecha
CREATE INDEX IF NOT EXISTS idx_recuperacion_fecha_creacion 
ON recuperacion_clave(fecha_creacion);
