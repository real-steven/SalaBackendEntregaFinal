-- Procedimiento para agregar servicios a una factura
CREATE PROCEDURE AgregarServicioAFactura
    @factura_id INT,
    @servicio_id INT,
    @cantidad INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @descripcion NVARCHAR(255);
    DECLARE @precio DECIMAL(10,2);
    DECLARE @error_msg NVARCHAR(500);
    
    BEGIN TRY
        -- Verificar que la factura existe y no está anulada
        IF NOT EXISTS (SELECT 1 FROM facturas WHERE id = @factura_id AND estado != 'anulada')
        BEGIN
            SET @error_msg = 'La factura no existe o está anulada';
            THROW 50005, @error_msg, 1;
        END
        
        -- Obtener información del servicio
        SELECT @descripcion = nombre, @precio = precio
        FROM servicios 
        WHERE id = @servicio_id;
        
        IF @descripcion IS NULL
        BEGIN
            SET @error_msg = 'El servicio no existe';
            THROW 50006, @error_msg, 1;
        END
        
        -- Verificar si el servicio ya está en la factura
        IF EXISTS (SELECT 1 FROM detallefactura WHERE factura_id = @factura_id AND tipo_item = 'servicio' AND item_id = @servicio_id)
        BEGIN
            -- Actualizar cantidad
            UPDATE detallefactura 
            SET cantidad = cantidad + @cantidad,
                subtotal = (cantidad + @cantidad) * precio_unitario
            WHERE factura_id = @factura_id AND tipo_item = 'servicio' AND item_id = @servicio_id;
        END
        ELSE
        BEGIN
            -- Agregar nuevo servicio
            INSERT INTO detallefactura (factura_id, tipo_item, item_id, descripcion, cantidad, precio_unitario, subtotal)
            VALUES (@factura_id, 'servicio', @servicio_id, @descripcion, @cantidad, @precio, @cantidad * @precio);
        END
        
        SELECT 'Servicio agregado correctamente' AS mensaje;
        
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;