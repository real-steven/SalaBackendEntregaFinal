-- Trigger para recalcular totales cuando se elimina un detalle
CREATE TRIGGER tr_detallefactura_eliminar
ON detallefactura
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Actualizar totales en factura después de eliminar detalle
    UPDATE f
    SET subtotal = (
        SELECT ISNULL(SUM(df.subtotal), 0)
        FROM detallefactura df
        WHERE df.factura_id = f.id
    ),
    total = (
        SELECT ISNULL(SUM(df.subtotal), 0) + f.impuestos
        FROM detallefactura df
        WHERE df.factura_id = f.id
    )
    FROM facturas f
    WHERE f.id IN (SELECT DISTINCT factura_id FROM deleted);
END;