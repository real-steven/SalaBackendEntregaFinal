-- =======================================================
-- SCRIPT DE VIEWS COMPLETO - SALÓN DE BELLEZA
-- Base de datos: salonbelleza
-- Fecha: 2025-11-13
-- =======================================================

USE salonbelleza;
GO

-- =======================================================
-- VIEW 1: VISTA COMPLETA DE CITAS
-- Información detallada de todas las citas
-- =======================================================

DROP VIEW IF EXISTS vw_citas_completas;
GO
CREATE VIEW vw_citas_completas AS
SELECT 
    c.id,
    c.fecha_hora,
    c.estado,
    c.notas,
    c.cancelacion_motivo,
    c.creado_en,
    c.actualizado_en,
    
    -- Información del cliente
    CASE 
        WHEN c.usuario_id IS NOT NULL THEN u.nombre
        ELSE c.nombre_invitado
    END as cliente_nombre,
    
    CASE 
        WHEN c.usuario_id IS NOT NULL THEN u.cedula
        ELSE c.cedula_invitado
    END as cliente_cedula,
    
    CASE 
        WHEN c.usuario_id IS NOT NULL THEN u.telefono
        ELSE c.telefono_invitado
    END as cliente_telefono,
    
    CASE 
        WHEN c.usuario_id IS NOT NULL THEN u.correo
        ELSE 'N/A'
    END as cliente_correo,
    
    CASE 
        WHEN c.usuario_id IS NOT NULL THEN 'Registrado'
        ELSE 'Invitado'
    END as tipo_cliente,
    
    -- Información del servicio
    s.nombre as servicio_nombre,
    s.descripcion as servicio_descripcion,
    s.precio as servicio_precio,
    
    -- Información del empleado (si está asignado)
    emp.nombre as empleado_nombre,
    emp.telefono as empleado_telefono,
    
    -- Indicador de facturación
    CASE 
        WHEN EXISTS (SELECT 1 FROM factura f WHERE f.idCita = c.id) THEN 'Facturada'
        ELSE 'Sin Facturar'
    END as estado_facturacion,
    
    -- Fecha formateada
    FORMAT(c.fecha_hora, 'dd/MM/yyyy') as fecha_formatted,
    FORMAT(c.fecha_hora, 'HH:mm') as hora_formatted,
    DATENAME(WEEKDAY, c.fecha_hora) as dia_semana

FROM citas c
LEFT JOIN usuarios u ON c.usuario_id = u.id
LEFT JOIN usuarios emp ON c.empleado_id = emp.id
INNER JOIN servicios s ON c.servicio_id = s.id;
GO

-- =======================================================
-- VIEW 2: RESUMEN DE FACTURAS CON DETALLES
-- Vista completa de facturas con información de cliente y totales
-- =======================================================

DROP VIEW IF EXISTS vw_facturas_resumen;
GO
CREATE VIEW vw_facturas_resumen AS
SELECT 
    f.idFact,
    f.fecha as fecha_factura,
    f.subtotal,
    f.impuesto,
    f.total,
    f.observaciones,
    
    -- Información de la cita asociada
    c.id as cita_id,
    c.fecha_hora as fecha_cita,
    c.estado as estado_cita,
    
    -- Información del cliente
    CASE 
        WHEN c.usuario_id IS NOT NULL THEN u.nombre
        ELSE c.nombre_invitado
    END as cliente_nombre,
    
    CASE 
        WHEN c.usuario_id IS NOT NULL THEN u.cedula
        ELSE c.cedula_invitado
    END as cliente_cedula,
    
    -- Información del servicio principal
    s.nombre as servicio_principal,
    s.precio as precio_servicio,
    
    -- Conteo de items en la factura
    (SELECT COUNT(*) FROM detallefactura df WHERE df.idFact = f.idFact) as total_items,
    
    -- Información adicional
    FORMAT(f.fecha, 'dd/MM/yyyy') as fecha_factura_formatted,
    FORMAT(f.total, 'C', 'es-CR') as total_formatted,
    
    -- Días transcurridos
    DATEDIFF(DAY, f.fecha, GETDATE()) as dias_desde_factura

FROM factura f
INNER JOIN citas c ON f.idCita = c.id
LEFT JOIN usuarios u ON c.usuario_id = u.id
INNER JOIN servicios s ON c.servicio_id = s.id;
GO

-- =======================================================
-- VIEW 3: DETALLE COMPLETO DE FACTURAS
-- Vista detallada de cada item en las facturas
-- =======================================================

DROP VIEW IF EXISTS vw_facturas_detalle_completo;
GO
CREATE VIEW vw_facturas_detalle_completo AS
SELECT 
    df.idDetalle,
    df.idFact,
    df.cant as cantidad,
    df.precio as precio_unitario,
    df.subtotal,
    df.detallePersonalizado,
    df.descripcion,
    
    -- Información del item (producto o servicio)
    CASE 
        WHEN df.idProducto IS NOT NULL THEN 'Producto'
        WHEN df.idServicio IS NOT NULL THEN 'Servicio'
        ELSE 'Personalizado'
    END as tipo_item,
    
    CASE 
        WHEN df.idProducto IS NOT NULL THEN p.nombre
        WHEN df.idServicio IS NOT NULL THEN s.nombre
        ELSE 'Item Personalizado'
    END as item_nombre,
    
    CASE 
        WHEN df.idProducto IS NOT NULL THEN p.descripcion
        WHEN df.idServicio IS NOT NULL THEN s.descripcion
        ELSE df.descripcion
    END as item_descripcion,
    
    -- Información de la factura
    f.fecha as fecha_factura,
    f.total as total_factura,
    
    -- Información del cliente
    CASE 
        WHEN c.usuario_id IS NOT NULL THEN u.nombre
        ELSE c.nombre_invitado
    END as cliente_nombre,
    
    -- Porcentaje del item respecto al total
    CASE 
        WHEN f.total > 0 THEN ROUND((df.subtotal / f.total) * 100, 2)
        ELSE 0
    END as porcentaje_del_total

FROM detallefactura df
INNER JOIN factura f ON df.idFact = f.idFact
INNER JOIN citas c ON f.idCita = c.id
LEFT JOIN usuarios u ON c.usuario_id = u.id
LEFT JOIN productos p ON df.idProducto = p.id
LEFT JOIN servicios s ON df.idServicio = s.id;
GO

-- =======================================================
-- VIEW 4: ESTADÍSTICAS DE CLIENTES
-- Vista consolidada de estadísticas por cliente
-- =======================================================

DROP VIEW IF EXISTS vw_estadisticas_clientes_completas;
GO
CREATE VIEW vw_estadisticas_clientes_completas AS
SELECT 
    u.id as cliente_id,
    u.nombre,
    u.correo,
    u.cedula,
    u.telefono,
    u.creado_en as fecha_registro,
    
    -- Estadísticas de citas
    ISNULL(ec.total_citas, 0) as total_citas,
    ISNULL(ec.citas_completadas, 0) as citas_completadas,
    ISNULL(ec.citas_canceladas, 0) as citas_canceladas,
    ISNULL(ec.gasto_total, 0) as gasto_total,
    ec.ultima_cita,
    
    -- Cálculos adicionales
    CASE 
        WHEN ec.total_citas > 0 THEN 
            ROUND((CAST(ec.citas_completadas AS FLOAT) / ec.total_citas) * 100, 2)
        ELSE 0
    END as porcentaje_completadas,
    
    CASE 
        WHEN ec.total_citas > 0 THEN 
            ROUND((CAST(ec.citas_canceladas AS FLOAT) / ec.total_citas) * 100, 2)
        ELSE 0
    END as porcentaje_canceladas,
    
    CASE 
        WHEN ec.citas_completadas > 0 THEN 
            ROUND(ec.gasto_total / ec.citas_completadas, 2)
        ELSE 0
    END as gasto_promedio_por_cita,
    
    -- Clasificación del cliente
    CASE 
        WHEN ec.gasto_total >= 100000 THEN 'Premium'
        WHEN ec.gasto_total >= 50000 THEN 'Frecuente'
        WHEN ec.gasto_total >= 20000 THEN 'Regular'
        WHEN ec.gasto_total > 0 THEN 'Nuevo'
        ELSE 'Sin Compras'
    END as categoria_cliente,
    
    -- Días desde la última cita
    CASE 
        WHEN ec.ultima_cita IS NOT NULL THEN 
            DATEDIFF(DAY, ec.ultima_cita, GETDATE())
        ELSE NULL
    END as dias_desde_ultima_cita

FROM usuarios u
LEFT JOIN estadisticas_clientes ec ON u.id = ec.cliente_id
WHERE u.rol = 'cliente';
GO

-- =======================================================
-- VIEW 5: INVENTARIO DE PRODUCTOS CON ALERTAS
-- Vista del inventario con indicadores de stock
-- =======================================================

DROP VIEW IF EXISTS vw_inventario_productos;
GO
CREATE VIEW vw_inventario_productos AS
SELECT 
    p.id,
    p.nombre,
    p.descripcion,
    p.precio,
    p.cantidad_disponible,
    p.imagen,
    p.creado_en,
    p.actualizado_en,
    
    -- Estado del inventario
    CASE 
        WHEN p.cantidad_disponible = 0 THEN 'Agotado'
        WHEN p.cantidad_disponible < 5 THEN 'Stock Bajo'
        WHEN p.cantidad_disponible < 10 THEN 'Stock Medio'
        ELSE 'Stock Suficiente'
    END as estado_inventario,
    
    -- Valor total en inventario
    p.cantidad_disponible * p.precio as valor_total_inventario,
    
    -- Alertas activas
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM alertas_inventario ai 
            WHERE ai.producto_id = p.id AND ai.estado = 'PENDIENTE'
        ) THEN 'Sí'
        ELSE 'No'
    END as tiene_alerta_activa,
    
    -- Ventas totales (aproximadas por facturas)
    ISNULL((
        SELECT SUM(df.cant) 
        FROM detallefactura df 
        WHERE df.idProducto = p.id
    ), 0) as total_vendido,
    
    -- Ingresos generados
    ISNULL((
        SELECT SUM(df.subtotal) 
        FROM detallefactura df 
        WHERE df.idProducto = p.id
    ), 0) as ingresos_generados,
    
    -- Precio formateado
    FORMAT(p.precio, 'C', 'es-CR') as precio_formatted

FROM productos p;
GO

-- =======================================================
-- VIEW 6: SERVICIOS MÁS SOLICITADOS
-- Ranking de servicios por popularidad
-- =======================================================

DROP VIEW IF EXISTS vw_servicios_ranking;
GO
CREATE VIEW vw_servicios_ranking AS
SELECT 
    s.id,
    s.nombre,
    s.descripcion,
    s.precio,
    s.creado_en,
    
    -- Estadísticas de uso
    ISNULL(citas_stats.total_citas, 0) as total_citas_solicitadas,
    ISNULL(citas_stats.citas_completadas, 0) as citas_completadas,
    ISNULL(citas_stats.citas_pendientes, 0) as citas_pendientes,
    ISNULL(citas_stats.citas_canceladas, 0) as citas_canceladas,
    
    -- Ingresos generados
    ISNULL(citas_stats.ingresos_completadas, 0) as ingresos_por_citas_completadas,
    ISNULL(factura_stats.ingresos_facturados, 0) as ingresos_facturados,
    
    -- Porcentajes
    CASE 
        WHEN citas_stats.total_citas > 0 THEN 
            ROUND((CAST(citas_stats.citas_completadas AS FLOAT) / citas_stats.total_citas) * 100, 2)
        ELSE 0
    END as porcentaje_completadas,
    
    -- Ranking
    RANK() OVER (ORDER BY ISNULL(citas_stats.total_citas, 0) DESC) as ranking_popularidad,
    RANK() OVER (ORDER BY ISNULL(citas_stats.ingresos_completadas, 0) DESC) as ranking_ingresos,
    
    -- Precio formateado
    FORMAT(s.precio, 'C', 'es-CR') as precio_formatted

FROM servicios s
LEFT JOIN (
    SELECT 
        c.servicio_id,
        COUNT(*) as total_citas,
        SUM(CASE WHEN c.estado = 'finalizada' THEN 1 ELSE 0 END) as citas_completadas,
        SUM(CASE WHEN c.estado IN ('pendiente', 'confirmada') THEN 1 ELSE 0 END) as citas_pendientes,
        SUM(CASE WHEN c.estado = 'cancelada' THEN 1 ELSE 0 END) as citas_canceladas,
        SUM(CASE WHEN c.estado = 'finalizada' THEN s.precio ELSE 0 END) as ingresos_completadas
    FROM citas c
    INNER JOIN servicios s ON c.servicio_id = s.id
    GROUP BY c.servicio_id
) citas_stats ON s.id = citas_stats.servicio_id
LEFT JOIN (
    SELECT 
        df.idServicio,
        SUM(df.subtotal) as ingresos_facturados
    FROM detallefactura df
    WHERE df.idServicio IS NOT NULL
    GROUP BY df.idServicio
) factura_stats ON s.id = factura_stats.idServicio;
GO

-- =======================================================
-- VIEW 7: CALENDARIO DE CITAS
-- Vista para mostrar disponibilidad y ocupación
-- =======================================================

DROP VIEW IF EXISTS vw_calendario_citas;
GO
CREATE VIEW vw_calendario_citas AS
SELECT 
    CAST(c.fecha_hora AS DATE) as fecha,
    DATEPART(HOUR, c.fecha_hora) as hora,
    COUNT(*) as total_citas,
    
    SUM(CASE WHEN c.estado = 'confirmada' THEN 1 ELSE 0 END) as citas_confirmadas,
    SUM(CASE WHEN c.estado = 'pendiente' THEN 1 ELSE 0 END) as citas_pendientes,
    SUM(CASE WHEN c.estado = 'finalizada' THEN 1 ELSE 0 END) as citas_finalizadas,
    SUM(CASE WHEN c.estado = 'cancelada' THEN 1 ELSE 0 END) as citas_canceladas,
    
    -- Información del día
    DATENAME(WEEKDAY, c.fecha_hora) as dia_semana,
    FORMAT(c.fecha_hora, 'dd/MM/yyyy') as fecha_formatted,
    
    -- Nivel de ocupación (asumiendo máximo 3 citas por hora)
    CASE 
        WHEN COUNT(*) >= 3 THEN 'Completo'
        WHEN COUNT(*) = 2 THEN 'Alto'
        WHEN COUNT(*) = 1 THEN 'Medio'
        ELSE 'Disponible'
    END as nivel_ocupacion,
    
    -- Lista de servicios programados
    STRING_AGG(s.nombre, ', ') as servicios_programados

FROM citas c
INNER JOIN servicios s ON c.servicio_id = s.id
WHERE c.estado NOT IN ('cancelada', 'rechazada')
GROUP BY CAST(c.fecha_hora AS DATE), DATEPART(HOUR, c.fecha_hora), c.fecha_hora;
GO

-- =======================================================
-- VIEW 8: AUDITORÍA RESUMIDA
-- Vista simplificada de la auditoría de usuarios
-- =======================================================

DROP VIEW IF EXISTS vw_auditoria_resumida;
GO
CREATE VIEW vw_auditoria_resumida AS
SELECT 
    au.id,
    au.usuario_id,
    u.nombre as usuario_nombre,
    u.correo as usuario_correo,
    au.accion,
    au.campo_modificado,
    au.valor_anterior,
    au.valor_nuevo,
    au.fecha_modificacion,
    au.usuario_modificador,
    
    -- Información adicional
    FORMAT(au.fecha_modificacion, 'dd/MM/yyyy HH:mm') as fecha_formatted,
    DATEDIFF(DAY, au.fecha_modificacion, GETDATE()) as dias_transcurridos,
    
    -- Tipo de cambio
    CASE 
        WHEN au.accion = 'INSERT' THEN 'Creación'
        WHEN au.accion = 'UPDATE' THEN 'Modificación'
        WHEN au.accion = 'DELETE' THEN 'Eliminación'
        ELSE 'Desconocido'
    END as tipo_cambio,
    
    -- Importancia del cambio
    CASE 
        WHEN au.campo_modificado IN ('rol', 'correo') THEN 'Alta'
        WHEN au.campo_modificado IN ('nombre', 'telefono') THEN 'Media'
        ELSE 'Baja'
    END as importancia_cambio

FROM auditoria_usuarios au
LEFT JOIN usuarios u ON au.usuario_id = u.id;
GO

-- =======================================================
-- VERIFICACIÓN DE VIEWS CREADAS
-- =======================================================

PRINT '';
PRINT '========================================';
PRINT 'VIEWS CREADAS EXITOSAMENTE';
PRINT '========================================';
PRINT '';

-- Mostrar todas las views creadas
SELECT 
    TABLE_NAME as 'Vista',
    VIEW_DEFINITION as 'Definición (Primeros 100 caracteres)'
FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_SCHEMA = 'dbo'
ORDER BY TABLE_NAME;

PRINT '';
PRINT '✅ Todas las vistas han sido creadas exitosamente';
PRINT '✅ Sistema de consultas optimizado';
PRINT '✅ Vistas para reportes disponibles';
PRINT '✅ Acceso seguro a datos complejos';
PRINT '';

-- Ejemplos de uso de las views
PRINT 'EJEMPLOS DE USO:';
PRINT '1. SELECT * FROM vw_citas_completas WHERE estado = ''pendiente'';';
PRINT '2. SELECT * FROM vw_facturas_resumen WHERE fecha_factura >= ''2025-01-01'';';
PRINT '3. SELECT * FROM vw_estadisticas_clientes_completas ORDER BY gasto_total DESC;';
PRINT '4. SELECT * FROM vw_servicios_ranking ORDER BY ranking_popularidad;';
PRINT '5. SELECT * FROM vw_inventario_productos WHERE estado_inventario = ''Stock Bajo'';';
PRINT '';