-- Procedimiento para obtener una factura con todos sus detalles
CREATE PROCEDURE ObtenerFacturaCompleta
    @factura_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Información de la factura
    SELECT 
        f.id,
        f.numero_factura,
        f.fecha_emision,
        f.subtotal,
        f.impuestos,
        f.total,
        f.estado,
        f.metodo_pago,
        f.notas,
        f.creado_en,
        f.actualizado_en,
        c.id AS cita_id,
        c.fecha_hora AS cita_fecha,
        c.estado AS cita_estado,
        s.nombre AS servicio_nombre,
        -- Información del cliente (puede ser usuario registrado o invitado)
        CASE 
            WHEN c.usuario_id IS NOT NULL THEN u.nombre
            ELSE c.nombre_invitado
        END AS cliente_nombre,
        CASE 
            WHEN c.usuario_id IS NOT NULL THEN u.cedula
            ELSE c.cedula_invitado
        END AS cliente_cedula,
        CASE 
            WHEN c.usuario_id IS NOT NULL THEN u.correo
            ELSE NULL
        END AS cliente_correo,
        CASE 
            WHEN c.usuario_id IS NOT NULL THEN NULL
            ELSE c.telefono_invitado
        END AS cliente_telefono
    FROM facturas f
    INNER JOIN citas c ON f.cita_id = c.id
    INNER JOIN servicios s ON c.servicio_id = s.id
    LEFT JOIN usuarios u ON c.usuario_id = u.id
    WHERE f.id = @factura_id;
    
    -- Detalles de la factura
    SELECT 
        df.id,
        df.tipo_item,
        df.item_id,
        df.descripcion,
        df.cantidad,
        df.precio_unitario,
        df.subtotal
    FROM detallefactura df
    WHERE df.factura_id = @factura_id
    ORDER BY df.id;
END;