-- 3. STORED PROCEDURES

-- Procedimiento para crear una factura completa desde una cita
CREATE PROCEDURE CrearFacturaDesdeCliente
    @cita_id INT,
    @metodo_pago NVARCHAR(50) = NULL,
    @impuestos DECIMAL(10,2) = 0,
    @notas TEXT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @factura_id INT;
    DECLARE @numero_factura NVARCHAR(50);
    DECLARE @error_msg NVARCHAR(500);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Verificar que la cita existe y está finalizada
        IF NOT EXISTS (SELECT 1 FROM citas WHERE id = @cita_id AND estado = 'finalizada')
        BEGIN
            SET @error_msg = 'La cita no existe o no está finalizada';
            THROW 50001, @error_msg, 1;
        END
        
        -- Verificar que no existe ya una factura para esta cita
        IF EXISTS (SELECT 1 FROM facturas WHERE cita_id = @cita_id)
        BEGIN
            SET @error_msg = 'Ya existe una factura para esta cita';
            THROW 50002, @error_msg, 1;
        END
        
        -- Generar número de factura único
        SET @numero_factura = 'FAC-' + FORMAT(GETDATE(), 'yyyyMMdd') + '-' + FORMAT(NEXT VALUE FOR seq_factura, '000000');
        
        -- Crear la factura
        INSERT INTO facturas (cita_id, numero_factura, subtotal, impuestos, total, metodo_pago, notas)
        VALUES (@cita_id, @numero_factura, 0, @impuestos, @impuestos, @metodo_pago, @notas);
        
        SET @factura_id = SCOPE_IDENTITY();
        
        -- Agregar el servicio como detalle de factura
        INSERT INTO detallefactura (factura_id, tipo_item, item_id, descripcion, cantidad, precio_unitario, subtotal)
        SELECT 
            @factura_id,
            'servicio',
            s.id,
            s.nombre,
            1,
            s.precio,
            s.precio
        FROM citas c
        INNER JOIN servicios s ON c.servicio_id = s.id
        WHERE c.id = @cita_id;
        
        COMMIT TRANSACTION;
        
        -- Retornar el ID de la factura creada
        SELECT @factura_id AS factura_id, @numero_factura AS numero_factura;
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;