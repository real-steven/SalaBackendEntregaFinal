-- =======================================================
-- SCRIPT DE TRIGGERS COMPLETO - SALÓN DE BELLEZA
-- Base de datos: salonbelleza
-- Fecha: 2025-11-13
-- =======================================================

USE salonbelleza;
GO

-- =======================================================
-- TRIGGER 1: AUDITORÍA DE USUARIOS
-- Registra todos los cambios en la tabla usuarios
-- =======================================================

DROP TRIGGER IF EXISTS tr_auditoria_usuarios;
GO
CREATE TRIGGER tr_auditoria_usuarios
ON usuarios
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Para INSERT
    IF EXISTS(SELECT * FROM inserted) AND NOT EXISTS(SELECT * FROM deleted)
    BEGIN
        INSERT INTO auditoria_usuarios (usuario_id, accion, campo_modificado, valor_nuevo, usuario_modificador)
        SELECT id, 'INSERT', 'registro_completo', 
               CONCAT('Nombre:', nombre, ' Email:', correo, ' Rol:', rol, ' Cedula:', cedula), 
               SYSTEM_USER
        FROM inserted;
        
        PRINT 'Trigger: Usuario registrado en auditoría - INSERT';
    END
    
    -- Para UPDATE
    IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
    BEGIN
        -- Cambios en nombre
        INSERT INTO auditoria_usuarios (usuario_id, accion, campo_modificado, valor_anterior, valor_nuevo, usuario_modificador)
        SELECT i.id, 'UPDATE', 'nombre', d.nombre, i.nombre, SYSTEM_USER
        FROM inserted i INNER JOIN deleted d ON i.id = d.id
        WHERE i.nombre != d.nombre;
        
        -- Cambios en correo
        INSERT INTO auditoria_usuarios (usuario_id, accion, campo_modificado, valor_anterior, valor_nuevo, usuario_modificador)
        SELECT i.id, 'UPDATE', 'correo', d.correo, i.correo, SYSTEM_USER
        FROM inserted i INNER JOIN deleted d ON i.id = d.id
        WHERE i.correo != d.correo;
        
        -- Cambios en rol
        INSERT INTO auditoria_usuarios (usuario_id, accion, campo_modificado, valor_anterior, valor_nuevo, usuario_modificador)
        SELECT i.id, 'UPDATE', 'rol', d.rol, i.rol, SYSTEM_USER
        FROM inserted i INNER JOIN deleted d ON i.id = d.id
        WHERE i.rol != d.rol;
        
        -- Cambios en teléfono
        INSERT INTO auditoria_usuarios (usuario_id, accion, campo_modificado, valor_anterior, valor_nuevo, usuario_modificador)
        SELECT i.id, 'UPDATE', 'telefono', d.telefono, i.telefono, SYSTEM_USER
        FROM inserted i INNER JOIN deleted d ON i.id = d.id
        WHERE ISNULL(i.telefono, '') != ISNULL(d.telefono, '');
        
        PRINT 'Trigger: Cambios de usuario registrados en auditoría - UPDATE';
    END
    
    -- Para DELETE
    IF EXISTS(SELECT * FROM deleted) AND NOT EXISTS(SELECT * FROM inserted)
    BEGIN
        INSERT INTO auditoria_usuarios (usuario_id, accion, campo_modificado, valor_anterior, usuario_modificador)
        SELECT id, 'DELETE', 'registro_completo', 
               CONCAT('Nombre:', nombre, ' Email:', correo, ' Rol:', rol, ' Cedula:', cedula),
               SYSTEM_USER
        FROM deleted;
        
        PRINT 'Trigger: Usuario eliminado registrado en auditoría - DELETE';
    END
END;
GO

-- =======================================================
-- TRIGGER 2: CONTROL DE INVENTARIO DE PRODUCTOS
-- Monitorea el stock y genera alertas automáticas
-- =======================================================

DROP TRIGGER IF EXISTS tr_control_inventario_productos;
GO
CREATE TRIGGER tr_control_inventario_productos
ON productos
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Verificar si el stock está bajo (menos de 5 unidades)
    IF EXISTS(SELECT * FROM inserted WHERE cantidad_disponible < 5)
    BEGIN
        -- Insertar alerta para productos con stock bajo
        INSERT INTO alertas_inventario (producto_id, producto_nombre, cantidad_actual)
        SELECT i.id, i.nombre, i.cantidad_disponible
        FROM inserted i
        WHERE i.cantidad_disponible < 5
        AND NOT EXISTS (
            SELECT 1 FROM alertas_inventario a 
            WHERE a.producto_id = i.id AND a.estado = 'PENDIENTE'
        );
        
        PRINT 'Trigger: Alerta de inventario bajo generada';
    END
    
    -- Marcar como resueltas las alertas de productos que ya tienen stock suficiente
    UPDATE alertas_inventario 
    SET estado = 'RESUELTO', fecha_alerta = GETDATE()
    WHERE producto_id IN (SELECT id FROM inserted WHERE cantidad_disponible >= 5)
    AND estado = 'PENDIENTE';
    
    -- Actualizar fecha de modificación
    UPDATE productos 
    SET actualizado_en = GETDATE()
    WHERE id IN (SELECT id FROM inserted);
END;
GO

-- =======================================================
-- TRIGGER 3: HISTORIAL DE PRECIOS DE SERVICIOS
-- Registra todos los cambios de precios
-- =======================================================

DROP TRIGGER IF EXISTS tr_historial_precios_servicios;
GO
CREATE TRIGGER tr_historial_precios_servicios
ON servicios
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Solo registrar si el precio cambió
    IF UPDATE(precio)
    BEGIN
        INSERT INTO historial_precios_servicios (
            servicio_id, servicio_nombre, precio_anterior, precio_nuevo, 
            porcentaje_cambio, motivo
        )
        SELECT 
            i.id,
            i.nombre,
            d.precio,
            i.precio,
            CASE 
                WHEN d.precio > 0 THEN ROUND(((i.precio - d.precio) / d.precio) * 100, 2)
                ELSE 0
            END,
            CASE 
                WHEN i.precio > d.precio THEN 'Aumento de precio'
                WHEN i.precio < d.precio THEN 'Reducción de precio'
                ELSE 'Sin cambio'
            END
        FROM inserted i
        INNER JOIN deleted d ON i.id = d.id
        WHERE i.precio != d.precio;
        
        PRINT 'Trigger: Cambio de precio registrado en historial';
    END
    
    -- Actualizar fecha de modificación
    UPDATE servicios 
    SET actualizado_en = GETDATE()
    WHERE id IN (SELECT id FROM inserted);
END;
GO

-- =======================================================
-- TRIGGER 4: ESTADÍSTICAS DE CLIENTES
-- Mantiene actualizadas las estadísticas de cada cliente
-- =======================================================

DROP TRIGGER IF EXISTS tr_estadisticas_clientes;
GO
CREATE TRIGGER tr_estadisticas_clientes
ON citas
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Crear tabla temporal con clientes afectados
    DECLARE @clientes_afectados TABLE (cliente_id INT);
    
    -- Recopilar IDs de clientes afectados
    INSERT INTO @clientes_afectados (cliente_id)
    SELECT DISTINCT usuario_id FROM inserted WHERE usuario_id IS NOT NULL
    UNION
    SELECT DISTINCT usuario_id FROM deleted WHERE usuario_id IS NOT NULL;
    
    -- Actualizar estadísticas para cada cliente afectado
    MERGE estadisticas_clientes AS target
    USING (
        SELECT 
            ca.cliente_id,
            COUNT(*) as total_citas,
            SUM(CASE WHEN c.estado = 'finalizada' THEN 1 ELSE 0 END) as citas_completadas,
            SUM(CASE WHEN c.estado = 'cancelada' THEN 1 ELSE 0 END) as citas_canceladas,
            ISNULL(SUM(CASE WHEN c.estado = 'finalizada' THEN s.precio ELSE 0 END), 0) as gasto_total,
            MAX(CAST(c.fecha_hora AS DATE)) as ultima_cita
        FROM @clientes_afectados ca
        LEFT JOIN citas c ON ca.cliente_id = c.usuario_id
        LEFT JOIN servicios s ON c.servicio_id = s.id
        GROUP BY ca.cliente_id
    ) AS source ON target.cliente_id = source.cliente_id
    
    WHEN MATCHED THEN
        UPDATE SET
            total_citas = source.total_citas,
            citas_completadas = source.citas_completadas,
            citas_canceladas = source.citas_canceladas,
            gasto_total = source.gasto_total,
            ultima_cita = source.ultima_cita,
            fecha_actualizacion = GETDATE()
    
    WHEN NOT MATCHED THEN
        INSERT (cliente_id, total_citas, citas_completadas, citas_canceladas, gasto_total, ultima_cita)
        VALUES (source.cliente_id, source.total_citas, source.citas_completadas, 
                source.citas_canceladas, source.gasto_total, source.ultima_cita);
    
    PRINT 'Trigger: Estadísticas de clientes actualizadas';
END;
GO

-- =======================================================
-- TRIGGER 5: VALIDACIÓN DE CITAS
-- Valida horarios y previene conflictos
-- =======================================================

DROP TRIGGER IF EXISTS tr_validacion_citas;
GO
CREATE TRIGGER tr_validacion_citas
ON citas
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validar que no haya conflictos de horario para el mismo empleado
    IF EXISTS (
        SELECT 1 
        FROM inserted i
        INNER JOIN citas c ON i.empleado_id = c.empleado_id 
                           AND i.id != c.id
                           AND i.fecha_hora = c.fecha_hora
                           AND c.estado NOT IN ('cancelada', 'rechazada')
        WHERE i.empleado_id IS NOT NULL
    )
    BEGIN
        RAISERROR('Conflicto de horario: El empleado ya tiene una cita programada en ese horario', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    
    -- Validar que la fecha no sea en el pasado (solo para INSERT)
    IF EXISTS (
        SELECT 1 FROM inserted 
        WHERE fecha_hora < GETDATE()
        AND NOT EXISTS (SELECT 1 FROM deleted WHERE id = inserted.id)
    )
    BEGIN
        RAISERROR('No se pueden crear citas con fecha y hora pasadas', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    
    -- Validar horario de atención (8:00 AM a 6:00 PM)
    IF EXISTS (
        SELECT 1 FROM inserted 
        WHERE DATEPART(HOUR, fecha_hora) < 8 OR DATEPART(HOUR, fecha_hora) >= 18
    )
    BEGIN
        RAISERROR('Las citas solo pueden programarse entre 8:00 AM y 6:00 PM', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    
    -- Actualizar fecha de modificación
    UPDATE citas 
    SET actualizado_en = GETDATE()
    WHERE id IN (SELECT id FROM inserted);
    
    PRINT 'Trigger: Validaciones de cita completadas exitosamente';
END;
GO

-- =======================================================
-- TRIGGER 6: CALCULAR TOTALES EN FACTURAS
-- Actualiza automáticamente los totales de facturas
-- =======================================================

DROP TRIGGER IF EXISTS tr_detallefactura_calcular_totales;
GO
CREATE TRIGGER tr_detallefactura_calcular_totales
ON detallefactura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Actualizar subtotal en detalles insertados/modificados
    IF EXISTS(SELECT * FROM inserted)
    BEGIN
        UPDATE df
        SET subtotal = df.cant * df.precio
        FROM detallefactura df
        INNER JOIN inserted i ON df.idDetalle = i.idDetalle;
    END
    
    -- Recopilar todas las facturas afectadas
    DECLARE @facturas_afectadas TABLE (idFact INT);
    
    INSERT INTO @facturas_afectadas (idFact)
    SELECT DISTINCT idFact FROM inserted
    UNION
    SELECT DISTINCT idFact FROM deleted;
    
    -- Actualizar totales en facturas afectadas
    UPDATE f
    SET 
        subtotal = ISNULL((
            SELECT SUM(df.subtotal)
            FROM detallefactura df
            WHERE df.idFact = f.idFact
        ), 0),
        impuesto = ISNULL((
            SELECT SUM(df.subtotal) * 0.13
            FROM detallefactura df
            WHERE df.idFact = f.idFact
        ), 0),
        total = ISNULL((
            SELECT SUM(df.subtotal) * 1.13
            FROM detallefactura df
            WHERE df.idFact = f.idFact
        ), 0)
    FROM factura f
    WHERE f.idFact IN (SELECT idFact FROM @facturas_afectadas);
    
    PRINT 'Trigger: Totales de facturas recalculados';
END;
GO

-- =======================================================
-- TRIGGER 7: ACTUALIZAR INVENTARIO AL VENDER PRODUCTOS
-- Reduce automáticamente el inventario cuando se vende
-- =======================================================

DROP TRIGGER IF EXISTS tr_actualizar_inventario_venta;
GO
CREATE TRIGGER tr_actualizar_inventario_venta
ON detallefactura
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Actualizar inventario solo para productos (no servicios)
    UPDATE p
    SET cantidad_disponible = p.cantidad_disponible - i.cant,
        actualizado_en = GETDATE()
    FROM productos p
    INNER JOIN inserted i ON p.id = i.idProducto
    WHERE i.idProducto IS NOT NULL;
    
    -- Verificar si algún producto quedó con inventario negativo
    IF EXISTS (
        SELECT 1 FROM productos p
        INNER JOIN inserted i ON p.id = i.idProducto
        WHERE p.cantidad_disponible < 0
    )
    BEGIN
        RAISERROR('Error: No hay suficiente inventario para completar la venta', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    
    PRINT 'Trigger: Inventario actualizado por venta de productos';
END;
GO

-- =======================================================
-- TRIGGER 8: LOG DE CAMBIOS EN SERVICIOS
-- Registra todos los cambios en servicios
-- =======================================================

DROP TRIGGER IF EXISTS tr_log_cambios_servicios;
GO
CREATE TRIGGER tr_log_cambios_servicios
ON servicios
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Para cambios en nombre del servicio
    IF UPDATE(nombre)
    BEGIN
        INSERT INTO historial_precios_servicios (
            servicio_id, servicio_nombre, precio_anterior, precio_nuevo, 
            porcentaje_cambio, motivo
        )
        SELECT 
            i.id, i.nombre, d.precio, i.precio, 0,
            'Cambio de nombre: ' + d.nombre + ' -> ' + i.nombre
        FROM inserted i
        INNER JOIN deleted d ON i.id = d.id
        WHERE i.nombre != d.nombre;
    END
    
    -- Para nuevos servicios
    IF EXISTS(SELECT * FROM inserted) AND NOT EXISTS(SELECT * FROM deleted)
    BEGIN
        INSERT INTO historial_precios_servicios (
            servicio_id, servicio_nombre, precio_anterior, precio_nuevo, 
            porcentaje_cambio, motivo
        )
        SELECT 
            i.id, i.nombre, 0, i.precio, 0, 'Nuevo servicio creado'
        FROM inserted i;
    END
    
    PRINT 'Trigger: Cambios en servicios registrados';
END;
GO

-- =======================================================
-- VERIFICACIÓN DE TRIGGERS CREADOS
-- =======================================================

PRINT '';
PRINT '========================================';
PRINT 'TRIGGERS CREADOS EXITOSAMENTE';
PRINT '========================================';
PRINT '';

-- Mostrar todos los triggers activos
SELECT 
    t.name AS 'Trigger',
    tb.name AS 'Tabla',
    CASE WHEN t.is_disabled = 0 THEN 'Activo' ELSE 'Desactivado' END as 'Estado',
    t.create_date AS 'Fecha Creación'
FROM sys.triggers t
INNER JOIN sys.tables tb ON t.parent_id = tb.object_id
WHERE tb.schema_id = SCHEMA_ID('dbo')
ORDER BY tb.name, t.name;

PRINT '';
PRINT '✅ Todos los triggers han sido creados y están activos';
PRINT '✅ Sistema de auditoría configurado';
PRINT '✅ Control de inventario automático';
PRINT '✅ Validaciones de negocio implementadas';
PRINT '';