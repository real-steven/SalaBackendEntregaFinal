-- =======================================================
-- SCRIPT MAESTRO COMPLETO - SALÓN DE BELLEZA
-- Base de datos completa para SQL Server
-- Fecha: 2025-11-11
-- =======================================================

USE master;
GO

-- Crear base de datos si no existe
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'salonbelleza')
BEGIN
    CREATE DATABASE salonbelleza;
    PRINT 'Base de datos salonbelleza creada';
END
ELSE
BEGIN
    PRINT 'Base de datos salonbelleza ya existe';
END
GO

USE salonbelleza;
GO

-- =======================================================
-- SECCIÓN 0: LIMPIAR SCHEMA ANTERIOR SI ES NECESARIO
-- =======================================================

-- Verificar y limpiar triggers conflictivos
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_validacion_citas')
    DROP TRIGGER tr_validacion_citas;

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_estadisticas_clientes')
    DROP TRIGGER tr_estadisticas_clientes;

-- Si la tabla citas existe con estructura incorrecta, la eliminamos
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'citas') AND type in (N'U'))
BEGIN
    -- Verificar si tiene columnas fecha y hora separadas (estructura antigua)
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'citas') AND name = 'fecha')
       AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'citas') AND name = 'hora')
    BEGIN
        PRINT 'Detectada estructura antigua de citas con fecha/hora separadas. Eliminando tabla...';
        DROP TABLE citas;
        PRINT 'Tabla citas eliminada - se recreará con estructura correcta';
    END
    ELSE
    BEGIN
        PRINT 'Tabla citas tiene estructura correcta con fecha_hora';
    END
END

-- =======================================================
-- SECCIÓN 1: CREACIÓN DE TABLAS PRINCIPALES
-- =======================================================

-- Tabla de usuarios
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'usuarios') AND type in (N'U'))
BEGIN
    CREATE TABLE usuarios (
        id INT IDENTITY(1,1) PRIMARY KEY,
        nombre NVARCHAR(100) NOT NULL,
        correo NVARCHAR(100) NOT NULL UNIQUE,
        cedula NVARCHAR(20) NOT NULL UNIQUE,
        contrasena NVARCHAR(100) NOT NULL,
        rol NVARCHAR(20) NOT NULL,
        telefono NVARCHAR(20) NULL,
        creado_en DATETIME DEFAULT GETDATE(),
        actualizado_en DATETIME NULL,
        CONSTRAINT CHK_usuarios_rol CHECK (rol IN ('admin', 'empleado', 'cliente'))
    );
    PRINT 'Tabla usuarios creada';
END
GO

-- Tabla de servicios
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'servicios') AND type in (N'U'))
BEGIN
    CREATE TABLE servicios (
        id INT IDENTITY(1,1) PRIMARY KEY,
        nombre NVARCHAR(100) NOT NULL,
        descripcion NVARCHAR(255),
        precio DECIMAL(10,2) NOT NULL,
        creado_en DATETIME DEFAULT GETDATE(),
        actualizado_en DATETIME NULL
    );
    PRINT 'Tabla servicios creada';
END
GO

-- Tabla de productos
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'productos') AND type in (N'U'))
BEGIN
    CREATE TABLE productos (
        id INT IDENTITY(1,1) PRIMARY KEY,
        nombre NVARCHAR(100) NOT NULL,
        descripcion NVARCHAR(255),
        precio DECIMAL(10,2) NOT NULL,
        imagen NVARCHAR(255),
        cantidad_disponible INT NOT NULL DEFAULT 0,
        creado_en DATETIME DEFAULT GETDATE(),
        actualizado_en DATETIME NULL
    );
    PRINT 'Tabla productos creada';
END
GO

-- Tabla de citas
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'citas') AND type in (N'U'))
BEGIN
    CREATE TABLE citas (
        id INT IDENTITY(1,1) PRIMARY KEY,
        usuario_id INT NULL,
        empleado_id INT NULL,
        servicio_id INT NOT NULL,
        fecha_hora DATETIME NOT NULL,
        estado NVARCHAR(20) NOT NULL DEFAULT 'pendiente',
        notas NVARCHAR(500) NULL,
        cancelacion_motivo NVARCHAR(255) NULL,
        cedula_invitado NVARCHAR(20) NULL,
        nombre_invitado NVARCHAR(100) NULL,
        telefono_invitado NVARCHAR(20) NULL,
        creado_en DATETIME DEFAULT GETDATE(),
        actualizado_en DATETIME NULL,
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
        FOREIGN KEY (servicio_id) REFERENCES servicios(id),
        CONSTRAINT CHK_citas_estado CHECK (estado IN ('pendiente', 'confirmada', 'rechazada', 'cancelada', 'atendida', 'finalizada'))
    );
    PRINT 'Tabla citas creada';
END
GO

-- =======================================================
-- SECCIÓN 2: SISTEMA DE FACTURAS
-- =======================================================

-- Tabla principal de facturas
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'factura') AND type in (N'U'))
BEGIN
    CREATE TABLE factura (
        idFact INT IDENTITY(1,1) PRIMARY KEY,
        idCita INT NOT NULL,
        fecha DATE NOT NULL DEFAULT GETDATE(),
        impuesto DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        observaciones TEXT NULL,
        
        -- Clave foránea hacia citas
        CONSTRAINT FK_factura_cita FOREIGN KEY (idCita) REFERENCES citas(id)
    );
    PRINT 'Tabla factura creada';
END
GO

-- Tabla de detalles de factura
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'detallefactura') AND type in (N'U'))
BEGIN
    CREATE TABLE detallefactura (
        idDetalle INT IDENTITY(1,1) PRIMARY KEY,
        idFact INT NOT NULL,
        idProducto INT NULL,
        idServicio INT NULL,
        cant INT NOT NULL DEFAULT 1,
        precio DECIMAL(10,2) NOT NULL,
        subtotal DECIMAL(10,2) NOT NULL,
        detallePersonalizado TEXT NULL,
        descripcion TEXT NULL,
        
        -- Claves foráneas
        CONSTRAINT FK_detallefactura_factura FOREIGN KEY (idFact) REFERENCES factura(idFact),
        CONSTRAINT FK_detallefactura_producto FOREIGN KEY (idProducto) REFERENCES productos(id),
        CONSTRAINT FK_detallefactura_servicio FOREIGN KEY (idServicio) REFERENCES servicios(id),
        
        -- Validación: debe tener producto O servicio, no ambos
        CONSTRAINT CHK_producto_o_servicio CHECK (
            (idProducto IS NOT NULL AND idServicio IS NULL) OR 
            (idProducto IS NULL AND idServicio IS NOT NULL)
        )
    );
    PRINT 'Tabla detallefactura creada';
END
GO

-- =======================================================
-- SECCIÓN 3: TABLAS AUXILIARES PARA TRIGGERS
-- =======================================================

-- Tabla de auditoría de usuarios
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'auditoria_usuarios') AND type in (N'U'))
BEGIN
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
    PRINT 'Tabla auditoria_usuarios creada';
END
GO

-- Tabla de alertas de inventario
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
    PRINT 'Tabla alertas_inventario creada';
END
GO

-- Tabla de historial de precios de servicios
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'historial_precios_servicios') AND type in (N'U'))
BEGIN
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
    PRINT 'Tabla historial_precios_servicios creada';
END
GO

-- Tabla de estadísticas de clientes
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'estadisticas_clientes') AND type in (N'U'))
BEGIN
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
    PRINT 'Tabla estadisticas_clientes creada';
END
GO

-- =======================================================
-- SECCIÓN 4: ÍNDICES PARA OPTIMIZACIÓN
-- =======================================================

-- Índices para facturas
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_factura_idCita')
    CREATE INDEX IX_factura_idCita ON factura(idCita);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_detallefactura_idFact')
    CREATE INDEX IX_detallefactura_idFact ON detallefactura(idFact);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_detallefactura_idProducto')
    CREATE INDEX IX_detallefactura_idProducto ON detallefactura(idProducto);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_detallefactura_idServicio')
    CREATE INDEX IX_detallefactura_idServicio ON detallefactura(idServicio);

-- Índices para citas
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_citas_fecha_hora')
    CREATE INDEX IX_citas_fecha_hora ON citas(fecha_hora);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_citas_usuario_id')
    CREATE INDEX IX_citas_usuario_id ON citas(usuario_id);

PRINT 'Índices creados correctamente';

-- =======================================================
-- SECCIÓN 5: STORED PROCEDURES PRINCIPALES
-- =======================================================

-- Stored Procedures para USUARIOS
DROP PROCEDURE IF EXISTS CrearUsuario;
GO
CREATE PROCEDURE CrearUsuario
    @nombre NVARCHAR(100),
    @correo NVARCHAR(100),
    @cedula NVARCHAR(20),
    @contrasena NVARCHAR(100),
    @rol NVARCHAR(20),
    @telefono NVARCHAR(20) = NULL
AS
BEGIN
    INSERT INTO usuarios (nombre, correo, cedula, contrasena, rol, telefono)
    VALUES (@nombre, @correo, @cedula, @contrasena, @rol, @telefono);
END;
GO

DROP PROCEDURE IF EXISTS ListarUsuarios;
GO
CREATE PROCEDURE ListarUsuarios
AS
BEGIN
    SELECT * FROM usuarios ORDER BY nombre;
END;
GO

-- Stored Procedures para SERVICIOS
DROP PROCEDURE IF EXISTS CrearServicio;
GO
CREATE PROCEDURE CrearServicio
    @nombre NVARCHAR(100),
    @descripcion NVARCHAR(255),
    @precio DECIMAL(10,2)
AS
BEGIN
    INSERT INTO servicios (nombre, descripcion, precio)
    VALUES (@nombre, @descripcion, @precio);
END;
GO

DROP PROCEDURE IF EXISTS ListarServicios;
GO
CREATE PROCEDURE ListarServicios
AS
BEGIN
    SELECT * FROM servicios ORDER BY nombre;
END;
GO

DROP PROCEDURE IF EXISTS EliminarServicio;
GO
CREATE PROCEDURE EliminarServicio
    @id INT
AS
BEGIN
    DELETE FROM servicios WHERE id = @id;
END;
GO

-- Stored Procedures para PRODUCTOS
DROP PROCEDURE IF EXISTS CrearProducto;
GO
CREATE PROCEDURE CrearProducto
    @nombre NVARCHAR(100),
    @descripcion NVARCHAR(255),
    @precio DECIMAL(10,2),
    @imagen NVARCHAR(255),
    @cantidad_disponible INT
AS
BEGIN
    INSERT INTO productos (nombre, descripcion, precio, imagen, cantidad_disponible)
    VALUES (@nombre, @descripcion, @precio, @imagen, @cantidad_disponible);
END;
GO

-- =======================================================
-- SECCIÓN 6: STORED PROCEDURES DE FACTURAS
-- =======================================================

DROP PROCEDURE IF EXISTS GenerarFacturaDesdeCita;
GO
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
    SELECT @servicioId = servicio_id FROM citas WHERE id = @idCita;
    SELECT @precioServicio = precio FROM servicios WHERE id = @servicioId;
    
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
    FROM servicios s WHERE s.id = @servicioId;
    
    -- Retornar información de la factura creada
    SELECT @idFact as idFact, 'Factura creada exitosamente' as mensaje;
END;
GO

DROP PROCEDURE IF EXISTS ListarFacturas;
GO
CREATE PROCEDURE ListarFacturas
AS
BEGIN
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
        END as cliente_nombre
    FROM factura f
    INNER JOIN citas c ON f.idCita = c.id
    LEFT JOIN usuarios u ON c.usuario_id = u.id
    ORDER BY f.fecha DESC;
END;
GO

-- =======================================================
-- SECCIÓN 7: TRIGGERS DEL SISTEMA
-- =======================================================

-- 1. TRIGGER: Auditoría de usuarios
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
               CONCAT('Nombre:', nombre, ' Email:', correo, ' Rol:', rol), 
               SYSTEM_USER
        FROM inserted;
    END
    
    -- Para UPDATE
    IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
    BEGIN
        INSERT INTO auditoria_usuarios (usuario_id, accion, campo_modificado, valor_anterior, valor_nuevo, usuario_modificador)
        SELECT i.id, 'UPDATE', 'nombre', d.nombre, i.nombre, SYSTEM_USER
        FROM inserted i INNER JOIN deleted d ON i.id = d.id
        WHERE i.nombre != d.nombre;
        
        INSERT INTO auditoria_usuarios (usuario_id, accion, campo_modificado, valor_anterior, valor_nuevo, usuario_modificador)
        SELECT i.id, 'UPDATE', 'correo', d.correo, i.correo, SYSTEM_USER
        FROM inserted i INNER JOIN deleted d ON i.id = d.id
        WHERE i.correo != d.correo;
        
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
               CONCAT('Nombre:', nombre, ' Email:', correo, ' Rol:', rol),
               SYSTEM_USER
        FROM deleted;
    END
END;
GO

-- 2. TRIGGER: Control de inventario de productos
DROP TRIGGER IF EXISTS tr_control_inventario_productos;
GO
CREATE TRIGGER tr_control_inventario_productos
ON productos
AFTER UPDATE
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
    END
    
    -- Marcar como resueltas las alertas de productos que ya tienen stock suficiente
    UPDATE alertas_inventario 
    SET estado = 'RESUELTO', fecha_alerta = GETDATE()
    WHERE producto_id IN (SELECT id FROM inserted WHERE cantidad_disponible >= 5)
    AND estado = 'PENDIENTE';
END;
GO

-- 3. TRIGGER: Historial de precios de servicios
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

-- 4. TRIGGER: Estadísticas de clientes
DROP TRIGGER IF EXISTS tr_estadisticas_clientes;
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
END;
GO

-- 5. TRIGGER: Calcular totales en detalle de factura
DROP TRIGGER IF EXISTS tr_detallefactura_calcular_subtotal;
GO
CREATE TRIGGER tr_detallefactura_calcular_subtotal
ON detallefactura
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Actualizar subtotal en detalle
    UPDATE df
    SET subtotal = df.cant * df.precio
    FROM detallefactura df
    INNER JOIN inserted i ON df.idDetalle = i.idDetalle;
    
    -- Actualizar totales en factura
    UPDATE f
    SET subtotal = (
        SELECT ISNULL(SUM(df.subtotal), 0)
        FROM detallefactura df
        WHERE df.idFact = f.idFact
    ),
    total = (
        SELECT ISNULL(SUM(df.subtotal), 0) + f.impuesto
        FROM detallefactura df
        WHERE df.idFact = f.idFact
    )
    FROM factura f
    WHERE f.idFact IN (SELECT DISTINCT idFact FROM inserted);
END;
GO

-- =======================================================
-- SECCIÓN 8: DATOS DE EJEMPLO
-- =======================================================

-- Insertar usuarios de ejemplo (con contraseñas hasheadas con bcrypt)
IF NOT EXISTS (SELECT * FROM usuarios WHERE correo = 'admin@salon.com')
BEGIN
    INSERT INTO usuarios (nombre, correo, cedula, contrasena, rol, telefono) VALUES
    ('Administrador', 'admin@salon.com', '1234567890', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin', '8888-8888'),
    ('María García', 'maria@gmail.com', '0987654321', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'cliente', '8765-4321'),
    ('Juan Pérez', 'juan@gmail.com', '1122334455', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'cliente', '8876-5432'),
    ('Ana López', 'ana@salon.com', '2233445566', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'empleado', '8987-6543'),
    ('Carlos Ruiz', 'carlos@gmail.com', '3344556677', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'cliente', '8098-7654');
    
    PRINT 'Usuarios de ejemplo insertados con contraseñas hasheadas';
    PRINT 'Contraseña para todos los usuarios: password';
END
GO

-- Insertar servicios de ejemplo
IF NOT EXISTS (SELECT * FROM servicios WHERE nombre = 'Corte de Cabello')
BEGIN
    INSERT INTO servicios (nombre, descripcion, precio) VALUES
    ('Corte de Cabello', 'Corte profesional de cabello', 15000.00),
    ('Manicure', 'Arreglo completo de uñas', 8000.00),
    ('Pedicure', 'Arreglo completo de pies', 10000.00),
    ('Alisado', 'Tratamiento de alisado profesional', 45000.00),
    ('Tinte', 'Coloración completa del cabello', 25000.00),
    ('Mechas', 'Aplicación de mechas', 35000.00),
    ('Tratamiento Facial', 'Limpieza y tratamiento facial', 18000.00),
    ('Masaje Relajante', 'Masaje corporal relajante', 22000.00),
    ('Depilación', 'Depilación con cera', 12000.00),
    ('Maquillaje', 'Maquillaje profesional', 20000.00);
    
    PRINT 'Servicios de ejemplo insertados';
END
GO

-- La tabla productos está lista para recibir datos
-- No se insertan productos de ejemplo
PRINT 'Tabla productos lista - sin datos de ejemplo';
GO

-- La tabla citas está lista para recibir datos
-- No se insertan citas de ejemplo
PRINT 'Tabla citas lista - sin datos de ejemplo';
GO

-- =======================================================
-- VERIFICACIÓN FINAL
-- =======================================================

PRINT '';
PRINT '========================================';
PRINT 'SCRIPT MAESTRO EJECUTADO EXITOSAMENTE';
PRINT '========================================';
PRINT '';

-- Mostrar resumen de tablas creadas
SELECT 
    TABLE_NAME as 'Tabla',
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = t.TABLE_NAME) as 'Columnas'
FROM INFORMATION_SCHEMA.TABLES t
WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_SCHEMA = 'dbo'
ORDER BY TABLE_NAME;

PRINT '';
PRINT 'Conteo de registros por tabla:';

DECLARE @sql NVARCHAR(MAX) = '';
SELECT @sql = @sql + 'SELECT ''' + TABLE_NAME + ''' as Tabla, COUNT(*) as Registros FROM ' + TABLE_NAME + ' UNION ALL '
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_SCHEMA = 'dbo';

SET @sql = LEFT(@sql, LEN(@sql) - 10) + ' ORDER BY Tabla';
EXEC sp_executesql @sql;

PRINT '';
PRINT 'Triggers activos:';
SELECT 
    t.name AS trigger_name,
    tb.name AS table_name,
    CASE WHEN t.is_disabled = 0 THEN 'Activo' ELSE 'Desactivado' END as estado
FROM sys.triggers t
INNER JOIN sys.tables tb ON t.parent_id = tb.object_id
ORDER BY tb.name, t.name;

PRINT '';
PRINT '✅ Base de datos lista para usar';
PRINT '✅ Usuario admin: admin@salon.com / password';
PRINT '✅ Todos los usuarios de ejemplo usan la contraseña: password';
PRINT '✅ Puerto backend: 8080';
PRINT '✅ Puerto frontend: 4200';
PRINT '';