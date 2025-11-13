-- Procedimiento para actualizar estado de factura
CREATE PROCEDURE ActualizarEstadoFactura
    @factura_id INT,
    @nuevo_estado NVARCHAR(20),
    @metodo_pago NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @error_msg NVARCHAR(500);
    
    -- Validar que el estado es válido
    IF @nuevo_estado NOT IN ('pendiente', 'pagada', 'anulada')
    BEGIN
        SET @error_msg = 'Estado de factura inválido. Debe ser: pendiente, pagada o anulada';
        THROW 50003, @error_msg, 1;
    END
    
    -- Verificar que la factura existe
    IF NOT EXISTS (SELECT 1 FROM facturas WHERE id = @factura_id)
    BEGIN
        SET @error_msg = 'La factura no existe';
        THROW 50004, @error_msg, 1;
    END
    
    -- Actualizar la factura
    UPDATE facturas 
    SET estado = @nuevo_estado,
        metodo_pago = ISNULL(@metodo_pago, metodo_pago),
        actualizado_en = GETDATE()
    WHERE id = @factura_id;
    
    SELECT 'Factura actualizada correctamente' AS mensaje;
END;