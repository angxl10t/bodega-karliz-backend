-- ==============================================================================
-- Migración V26: Asignar correo oficial cajayapos@gmail.com al usuario 'admin'
-- ==============================================================================

UPDATE usuarios
SET email = 'cajayapos@gmail.com'
WHERE LOWER(username) = 'admin';
