-- =====================================================
-- ARCHIVO: 017_crear_triggers_sistema.sql
-- DESCRIPCIÓN: 5 Triggers útiles para el sistema del salón
-- FECHA: 2025-10-25
-- =====================================================

-- 1. TRIGGER: Auditoría de cambios en usuarios
-- Registra todos los cambios realizados en la tabla usuarios
CREATE TABLE auditoria_usuarios (
    id INT IDENTITY(1,1) PRIMARY KEY,
    usuario_id INT,
    accion VARCHAR(10), -- INSERT, UPDATE, DELETE
    campo_modificado VARCHAR(50),
    valor_anterior NVARCHAR(255),
    valor_nuevo NVARCHAR(255),
    fecha_modificacion DATETIME DEFAULT GETDATE(),
    usuario_modificador VARCHAR(100)
);

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
               CONCAT('Nombre:', nombre, ' Email:', email, ' Rol:', rol), 
               SYSTEM_USER
        FROM inserted;
    END
    
    -- Para UPDATE
    IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
    BEGIN
        -- Auditar cambio de nombre
        INSERT INTO auditoria_usuarios (usuario_id, accion, campo_modificado, valor_anterior, valor_nuevo, usuario_modificador)
        SELECT i.id, 'UPDATE', 'nombre', d.nombre, i.nombre, SYSTEM_USER
        FROM inserted i INNER JOIN deleted d ON i.id = d.id
        WHERE i.nombre != d.nombre;
        
        -- Auditar cambio de email
        INSERT INTO auditoria_usuarios (usuario_id, accion, campo_modificado, valor_anterior, valor_nuevo, usuario_modificador)
        SELECT i.id, 'UPDATE', 'email', d.email, i.email, SYSTEM_USER
        FROM inserted i INNER JOIN deleted d ON i.id = d.id
        WHERE i.email != d.email;
        
        -- Auditar cambio de rol
        INSERT INTO auditoria_usuarios (usuario_id, accion, campo_modificado, valor_anterior, valor_nuevo, usuario_modificador)
        SELECT i.id, 'UPDATE', 'rol', d.rol, i.rol, SYSTEM_USER
        FROM inserted i INNER JOIN deleted d ON i.id = d.id
        WHERE i.rol != d.rol;
    END
    
    -- Para DELETE
    IF EXISTS(SELECT * FROM deleted) AND NOT EXISTS(SELECT * FROM inserted)
    BEGIN
        INSERT INTO auditoria_usuarios (usuario_id, accion, campo_modificado, valor_anterior, usuario_modificador)
        SELECT id, 'DELETE', 'registro_completo', 
               CONCAT('Nombre:', nombre, ' Email:', email, ' Rol:', rol),
               SYSTEM_USER
        FROM deleted;
    END
END;

GO

-- 2. TRIGGER: Control de inventario de productos
-- Actualiza automáticamente el stock cuando se realizan operaciones
CREATE TRIGGER tr_control_inventario_productos
ON productos
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Verificar si el stock está bajo (menos de 5 unidades)
    IF EXISTS(SELECT * FROM inserted WHERE cantidad_disponible < 5)
    BEGIN
        -- Crear tabla de alertas si no existe
        IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'alertas_inventario') AND type in (N'U'))
        BEGIN
            CREATE TABLE alertas_inventario (
                id INT IDENTITY(1,1) PRIMARY KEY,
                producto_id INT,
                producto_nombre NVARCHAR(100),
                cantidad_actual INT,
                fecha_alerta DATETIME DEFAULT GETDATE(),
                estado VARCHAR(20) DEFAULT 'PENDIENTE'
            );
        END
        
        -- Insertar alerta para productos con stock bajo
        INSERT INTO alertas_inventario (producto_id, producto_nombre, cantidad_actual)
        SELECT i.id, i.nombre, i.cantidad_disponible
        FROM inserted i
        WHERE i.cantidad_disponible < 5
        AND NOT EXISTS (
            SELECT 1 FROM alertas_inventario a 
            WHERE a.producto_id = i.id AND a.estado = 'PENDIENTE'
        );
    END
    
    -- Marcar como resueltas las alertas de productos que ya tienen stock suficiente
    UPDATE alertas_inventario 
    SET estado = 'RESUELTO', fecha_alerta = GETDATE()
    WHERE producto_id IN (SELECT id FROM inserted WHERE cantidad_disponible >= 5)
    AND estado = 'PENDIENTE';
END;

GO

-- 3. TRIGGER: Validación automática de citas
-- Evita conflictos de horarios y valida reglas de negocio
CREATE TRIGGER tr_validacion_citas
ON citas
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validar que no haya citas superpuestas para el mismo horario
    IF EXISTS(
        SELECT 1 FROM inserted i
        INNER JOIN citas c ON c.fecha = i.fecha AND c.hora = i.hora 
        WHERE c.estado IN ('confirmada', 'pendiente')
        AND (
            (UPDATE(fecha) OR UPDATE(hora)) -- Es una actualización de fecha/hora
            OR NOT EXISTS(SELECT 1 FROM deleted d WHERE d.id = c.id) -- Es una inserción
        )
    )
    BEGIN
        RAISERROR('Ya existe una cita confirmada o pendiente para esa fecha y hora', 16, 1);
        RETURN;
    END
    
    -- Validar que la fecha sea futura (no se puedan crear citas en el pasado)
    IF EXISTS(
        SELECT 1 FROM inserted 
        WHERE CAST(fecha AS DATE) < CAST(GETDATE() AS DATE)
    )
    BEGIN
        RAISERROR('No se pueden crear citas en fechas pasadas', 16, 1);
        RETURN;
    END
    
    -- Validar horarios de trabajo (8:00 AM a 8:00 PM)
    IF EXISTS(
        SELECT 1 FROM inserted 
        WHERE CAST(hora AS TIME) < '08:00:00' OR CAST(hora AS TIME) > '20:00:00'
    )
    BEGIN
        RAISERROR('Las citas solo pueden ser agendadas entre las 8:00 AM y 8:00 PM', 16, 1);
        RETURN;
    END
    
    -- Si todas las validaciones pasan, realizar la operación
    IF EXISTS(SELECT * FROM inserted) AND NOT EXISTS(SELECT * FROM deleted)
    BEGIN
        -- INSERT
        INSERT INTO citas (cliente_id, servicio_id, fecha, hora, estado, notas, cedula_invitado, nombre_invitado, telefono_invitado)
        SELECT cliente_id, servicio_id, fecha, hora, estado, notas, cedula_invitado, nombre_invitado, telefono_invitado
        FROM inserted;
    END
    ELSE IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
    BEGIN
        -- UPDATE
        UPDATE c SET
            cliente_id = i.cliente_id,
            servicio_id = i.servicio_id,
            fecha = i.fecha,
            hora = i.hora,
            estado = i.estado,
            notas = i.notas,
            cedula_invitado = i.cedula_invitado,
            nombre_invitado = i.nombre_invitado,
            telefono_invitado = i.telefono_invitado
        FROM citas c
        INNER JOIN inserted i ON c.id = i.id;
    END
END;

GO

-- 4. TRIGGER: Historial de precios de servicios
-- Mantiene un registro de cambios de precios para análisis histórico
CREATE TABLE historial_precios_servicios (
    id INT IDENTITY(1,1) PRIMARY KEY,
    servicio_id INT,
    servicio_nombre NVARCHAR(100),
    precio_anterior DECIMAL(10,2),
    precio_nuevo DECIMAL(10,2),
    porcentaje_cambio DECIMAL(5,2),
    fecha_cambio DATETIME DEFAULT GETDATE(),
    motivo VARCHAR(200)
);

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
            servicio_id, servicio_nombre, precio_anterior, precio_nuevo, porcentaje_cambio
        )
        SELECT 
            i.id,
            i.nombre,
            d.precio,
            i.precio,
            CASE 
                WHEN d.precio > 0 THEN ROUND(((i.precio - d.precio) / d.precio) * 100, 2)
                ELSE 0
            END
        FROM inserted i
        INNER JOIN deleted d ON i.id = d.id
        WHERE i.precio != d.precio;
    END
END;

GO

-- 5. TRIGGER: Actualización automática de estadísticas de clientes
-- Mantiene estadísticas actualizadas de cada cliente
CREATE TABLE estadisticas_clientes (
    cliente_id INT PRIMARY KEY,
    total_citas INT DEFAULT 0,
    citas_completadas INT DEFAULT 0,
    citas_canceladas INT DEFAULT 0,
    gasto_total DECIMAL(12,2) DEFAULT 0,
    ultima_cita DATE,
    fecha_registro DATETIME DEFAULT GETDATE(),
    fecha_actualizacion DATETIME DEFAULT GETDATE()
);

GO

CREATE TRIGGER tr_estadisticas_clientes
ON citas
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Crear o actualizar estadísticas para clientes afectados
    DECLARE @clientes_afectados TABLE (cliente_id INT);
    
    -- Recopilar IDs de clientes afectados
    INSERT INTO @clientes_afectados (cliente_id)
    SELECT DISTINCT cliente_id FROM inserted WHERE cliente_id IS NOT NULL
    UNION
    SELECT DISTINCT cliente_id FROM deleted WHERE cliente_id IS NOT NULL;
    
    -- Actualizar estadísticas para cada cliente afectado
    MERGE estadisticas_clientes AS target
    USING (
        SELECT 
            ca.cliente_id,
            COUNT(*) as total_citas,
            SUM(CASE WHEN c.estado = 'completada' THEN 1 ELSE 0 END) as citas_completadas,
            SUM(CASE WHEN c.estado = 'cancelada' THEN 1 ELSE 0 END) as citas_canceladas,
            ISNULL(SUM(CASE WHEN c.estado = 'completada' THEN s.precio ELSE 0 END), 0) as gasto_total,
            MAX(c.fecha) as ultima_cita
        FROM @clientes_afectados ca
        LEFT JOIN citas c ON ca.cliente_id = c.cliente_id
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
END;

GO

-- =====================================================
-- CONSULTAS PARA VERIFICAR LOS TRIGGERS CREADOS
-- =====================================================

-- Verificar que todos los triggers se crearon correctamente
SELECT 
    t.name AS trigger_name,
    tb.name AS table_name,
    t.is_disabled,
    t.create_date
FROM sys.triggers t
INNER JOIN sys.tables tb ON t.parent_id = tb.object_id
WHERE t.name IN (
    'tr_auditoria_usuarios',
    'tr_control_inventario_productos', 
    'tr_validacion_citas',
    'tr_historial_precios_servicios',
    'tr_estadisticas_clientes'
)
ORDER BY t.create_date DESC;

-- =====================================================
-- CONSULTAS ÚTILES PARA USAR LAS NUEVAS FUNCIONALIDADES
-- =====================================================

-- 1. Ver auditoría de usuarios
-- SELECT * FROM auditoria_usuarios ORDER BY fecha_modificacion DESC;

-- 2. Ver alertas de inventario bajo
-- SELECT * FROM alertas_inventario WHERE estado = 'PENDIENTE';

-- 3. Ver historial de cambios de precios
-- SELECT * FROM historial_precios_servicios ORDER BY fecha_cambio DESC;

-- 4. Ver estadísticas de clientes
-- SELECT 
--     ec.*,
--     u.nombre,
--     u.email
-- FROM estadisticas_clientes ec
-- INNER JOIN usuarios u ON ec.cliente_id = u.id
-- ORDER BY ec.gasto_total DESC;

PRINT 'Todos los triggers han sido creados exitosamente!';
PRINT 'Se crearon 5 triggers y 3 tablas auxiliares para mejorar el sistema.';