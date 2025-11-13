-- 2. TRIGGERS

-- Trigger para actualizar fecha de modificación en facturas
CREATE TRIGGER tr_facturas_actualizado_en
ON facturas
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE facturas 
    SET actualizado_en = GETDATE()
    WHERE id IN (SELECT id FROM inserted);
END;