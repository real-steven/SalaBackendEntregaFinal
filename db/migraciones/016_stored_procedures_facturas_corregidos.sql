-- Corregir stored procedures de facturas

DROP PROCEDURE IF EXISTS GenerarFacturaDesdeCita;
DROP PROCEDURE IF EXISTS ObtenerFacturaCompleta;
DROP PROCEDURE IF EXISTS ObtenerFacturaPorCita;
DROP PROCEDURE IF EXISTS ListarFacturas;
GO

-- 1. Procedimiento para generar factura desde una cita finalizada
CREATE PROCEDURE GenerarFacturaDesdeCita
    @idCita INT,
    @observaciones TEXT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @idFact INT;
    DECLARE @precioServicio DECIMAL(10,2);
    DECLARE @impuesto DECIMAL(10,2);
    DECLARE @subtotal DECIMAL(10,2);
    DECLARE @total DECIMAL(10,2);
    DECLARE @servicioId INT;
    
    -- Verificar que la cita existe y está finalizada
    IF NOT EXISTS (SELECT 1 FROM citas WHERE id = @idCita AND estado = 'finalizada')
    BEGIN
        RAISERROR('La cita no existe o no está finalizada', 16, 1);
        RETURN;
    END
    
    -- Verificar que no ya existe factura para esta cita
    IF EXISTS (SELECT 1 FROM factura WHERE idCita = @idCita)
    BEGIN
        RAISERROR('Ya existe una factura para esta cita', 16, 1);
        RETURN;
    END
    
    -- Obtener información del servicio de la cita
    SELECT @servicioId = servicio_id 
    FROM citas 
    WHERE id = @idCita;
    
    SELECT @precioServicio = precio 
    FROM servicios 
    WHERE id = @servicioId;
    
    -- Calcular totales (13% de impuesto)
    SET @subtotal = @precioServicio;
    SET @impuesto = @subtotal * 0.13;
    SET @total = @subtotal + @impuesto;
    
    -- Crear la factura
    INSERT INTO factura (idCita, fecha, impuesto, subtotal, total, observaciones)
    VALUES (@idCita, GETDATE(), @impuesto, @subtotal, @total, @observaciones);
    
    SET @idFact = SCOPE_IDENTITY();
    
    -- Agregar el detalle del servicio
    INSERT INTO detallefactura (idFact, idServicio, cant, precio, subtotal, descripcion)
    SELECT @idFact, @servicioId, 1, @precioServicio, @precioServicio, 
           'Servicio: ' + s.nombre
    FROM servicios s 
    WHERE s.id = @servicioId;
    
    -- Retornar información de la factura creada
    SELECT 
        f.idFact,
        f.idCita,
        f.fecha,
        f.impuesto,
        f.subtotal,
        f.total,
        f.observaciones,
        c.fecha_hora as fecha_cita,
        s.nombre as servicio_nombre,
        CASE 
            WHEN c.usuario_id IS NOT NULL THEN u.nombre
            ELSE c.nombre_invitado
        END as cliente_nombre
    FROM factura f
    INNER JOIN citas c ON f.idCita = c.id
    INNER JOIN servicios s ON c.servicio_id = s.id
    LEFT JOIN usuarios u ON c.usuario_id = u.id
    WHERE f.idFact = @idFact;
    
END;
GO

-- 2. Procedimiento para obtener factura completa con detalles
CREATE PROCEDURE ObtenerFacturaCompleta
    @idFact INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Información principal de la factura
    SELECT 
        f.idFact,
        f.idCita,
        f.fecha,
        f.impuesto,
        f.subtotal,
        f.total,
        f.observaciones,
        c.fecha_hora as fecha_cita,
        CASE 
            WHEN c.usuario_id IS NOT NULL THEN u.nombre
            ELSE c.nombre_invitado
        END as cliente_nombre,
        CASE 
            WHEN c.usuario_id IS NOT NULL THEN u.cedula
            ELSE c.cedula_invitado
        END as cliente_cedula,
        CASE 
            WHEN c.usuario_id IS NOT NULL THEN u.correo
            ELSE 'No disponible'
        END as cliente_correo
    FROM factura f
    INNER JOIN citas c ON f.idCita = c.id
    LEFT JOIN usuarios u ON c.usuario_id = u.id
    WHERE f.idFact = @idFact;
    
    -- Detalles de la factura
    SELECT 
        df.idDetalle,
        df.cant,
        df.precio,
        df.subtotal,
        df.detallePersonalizado,
        df.descripcion,
        CASE 
            WHEN df.idProducto IS NOT NULL THEN 'Producto'
            WHEN df.idServicio IS NOT NULL THEN 'Servicio'
        END as tipo_item,
        CASE 
            WHEN df.idProducto IS NOT NULL THEN p.nombre
            WHEN df.idServicio IS NOT NULL THEN s.nombre
        END as nombre_item
    FROM detallefactura df
    LEFT JOIN productos p ON df.idProducto = p.id
    LEFT JOIN servicios s ON df.idServicio = s.id
    WHERE df.idFact = @idFact
    ORDER BY df.idDetalle;
    
END;
GO

-- 3. Procedimiento para obtener facturas por cita
CREATE PROCEDURE ObtenerFacturaPorCita
    @idCita INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        f.idFact,
        f.idCita,
        f.fecha,
        f.impuesto,
        f.subtotal,
        f.total,
        f.observaciones
    FROM factura f
    WHERE f.idCita = @idCita;
    
END;
GO

-- 4. Procedimiento para listar facturas
CREATE PROCEDURE ListarFacturas
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        f.idFact,
        f.idCita,
        f.fecha,
        f.impuesto,
        f.subtotal,
        f.total,
        f.observaciones,
        c.fecha_hora as fecha_cita,
        CASE 
            WHEN c.usuario_id IS NOT NULL THEN u.nombre
            ELSE c.nombre_invitado
        END as cliente_nombre,
        CASE 
            WHEN c.usuario_id IS NOT NULL THEN 'Registrado'
            ELSE 'Invitado'
        END as tipo_cliente
    FROM factura f
    INNER JOIN citas c ON f.idCita = c.id
    LEFT JOIN usuarios u ON c.usuario_id = u.id
    ORDER BY f.fecha DESC;
    
END;
GO

PRINT 'Stored procedures de facturas corregidos y creados correctamente';