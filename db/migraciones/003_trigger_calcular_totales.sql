-- Trigger para calcular automáticamente totales en detalle de factura
CREATE TRIGGER tr_detallefactura_calcular_subtotal
ON detallefactura
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Actualizar subtotal en detalle
    UPDATE df
    SET subtotal = df.cantidad * df.precio_unitario
    FROM detallefactura df
    INNER JOIN inserted i ON df.id = i.id;
    
    -- Actualizar totales en factura
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
    WHERE f.id IN (SELECT DISTINCT factura_id FROM inserted);
END;