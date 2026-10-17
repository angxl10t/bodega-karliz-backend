-- ==============================================================================
-- MIGRACIÓN V6: CAMPOS DE RESPUESTA TELEMÁTICA SUNAT (HASH, CDR, MENSAJE, URLs)
-- CajaYa Cloud POS Platform - Emisión REST UBL 2.1
-- ==============================================================================

ALTER TABLE ventas ADD COLUMN IF NOT EXISTS sunat_hash VARCHAR(100);
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS sunat_mensaje VARCHAR(255);
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS sunat_cdr_url VARCHAR(500);
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS sunat_pdf_url VARCHAR(500);
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS sunat_xml_url VARCHAR(500);

CREATE INDEX IF NOT EXISTS idx_ventas_estado_sunat ON ventas(estado_sunat);
