-- Procedimiento para agregar productos a una factura
CREATE PROCEDURE AgregarProductoAFactura
    @factura_id INT,
    @producto_id INT,
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
        
        -- Obtener información del producto
        SELECT @descripcion = nombre, @precio = precio
        FROM productos 
        WHERE id = @producto_id;
        
        IF @descripcion IS NULL
        BEGIN
            SET @error_msg = 'El producto no existe';
            THROW 50006, @error_msg, 1;
        END
        
        -- Verificar si el producto ya está en la factura
        IF EXISTS (SELECT 1 FROM detallefactura WHERE factura_id = @factura_id AND tipo_item = 'producto' AND item_id = @producto_id)
        BEGIN
            -- Actualizar cantidad
            UPDATE detallefactura 
            SET cantidad = cantidad + @cantidad,
                subtotal = (cantidad + @cantidad) * precio_unitario
            WHERE factura_id = @factura_id AND tipo_item = 'producto' AND item_id = @producto_id;
        END
        ELSE
        BEGIN
            -- Agregar nuevo producto
            INSERT INTO detallefactura (factura_id, tipo_item, item_id, descripcion, cantidad, precio_unitario, subtotal)
            VALUES (@factura_id, 'producto', @producto_id, @descripcion, @cantidad, @precio, @cantidad * @precio);
        END
        
        SELECT 'Producto agregado correctamente' AS mensaje;
        
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;