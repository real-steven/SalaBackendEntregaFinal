-- Procedimiento para listar todas las facturas
CREATE PROCEDURE ListarFacturas
    @estado NVARCHAR(20) = NULL,
    @fecha_desde DATETIME = NULL,
    @fecha_hasta DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        f.id,
        f.numero_factura,
        f.fecha_emision,
        f.subtotal,
        f.impuestos,
        f.total,
        f.estado,
        f.metodo_pago,
        c.id AS cita_id,
        c.fecha_hora AS cita_fecha,
        s.nombre AS servicio_nombre,
        -- Cliente info
        CASE 
            WHEN c.usuario_id IS NOT NULL THEN u.nombre
            ELSE c.nombre_invitado
        END AS cliente_nombre,
        CASE 
            WHEN c.usuario_id IS NOT NULL THEN u.cedula
            ELSE c.cedula_invitado
        END AS cliente_cedula,
        CASE 
            WHEN c.usuario_id IS NOT NULL THEN 'registrado'
            ELSE 'invitado'
        END AS tipo_cliente
    FROM facturas f
    INNER JOIN citas c ON f.cita_id = c.id
    INNER JOIN servicios s ON c.servicio_id = s.id
    LEFT JOIN usuarios u ON c.usuario_id = u.id
    WHERE (@estado IS NULL OR f.estado = @estado)
      AND (@fecha_desde IS NULL OR f.fecha_emision >= @fecha_desde)
      AND (@fecha_hasta IS NULL OR f.fecha_emision <= @fecha_hasta)
    ORDER BY f.fecha_emision DESC;
END;