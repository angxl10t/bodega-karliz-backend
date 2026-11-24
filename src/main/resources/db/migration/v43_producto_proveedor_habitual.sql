-- ==============================================================================
-- v43_producto_proveedor_habitual.sql
-- Vinculación explícita de proveedor habitual / distribuidor a productos
-- Permite reposición directa por proveedor y filtrado en compras
-- ==============================================================================

-- 1. Agregar columna id_proveedor nullable a la tabla productos
ALTER TABLE productos 
ADD COLUMN IF NOT EXISTS id_proveedor BIGINT REFERENCES proveedores(id_proveedor) ON DELETE SET NULL;

-- 2. Índice compuesto para filtrado de alta velocidad por bodega y proveedor
CREATE INDEX IF NOT EXISTS idx_productos_bodega_proveedor 
ON productos(id_bodega, id_proveedor);

-- 3. Poblado retroactivo inteligente: Vincular productos a proveedores con compras históricas
UPDATE productos p
SET id_proveedor = sub.id_proveedor
FROM (
    SELECT cd.id_producto, c.id_proveedor
    FROM compras_detalles cd
    INNER JOIN compras c ON c.id_compra = cd.id_compra
    WHERE c.id_proveedor IS NOT NULL
    GROUP BY cd.id_producto, c.id_proveedor
) sub
WHERE p.id_producto = sub.id_producto 
  AND p.id_proveedor IS NULL;
