-- Tabla de usuarios
CREATE TABLE usuarios (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100) NOT NULL,
    correo NVARCHAR(100) NOT NULL UNIQUE,
    cedula NVARCHAR(20) NOT NULL UNIQUE,
    contrasena NVARCHAR(100) NOT NULL,
    rol NVARCHAR(20) NOT NULL,
    creado_en DATETIME DEFAULT GETDATE(),
    actualizado_en DATETIME NULL
);

-- Tabla de servicios
CREATE TABLE servicios (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100) NOT NULL,
    descripcion NVARCHAR(255),
    precio DECIMAL(10,2) NOT NULL,
    creado_en DATETIME DEFAULT GETDATE(),
    actualizado_en DATETIME NULL
);

-- Tabla de productos
CREATE TABLE productos (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100) NOT NULL,
    descripcion NVARCHAR(255),
    precio DECIMAL(10,2) NOT NULL,
    imagen NVARCHAR(255),
    cantidad_disponible INT NOT NULL,
    creado_en DATETIME DEFAULT GETDATE(),
    actualizado_en DATETIME NULL
);

-- Tabla de citas
CREATE TABLE citas (
    id INT IDENTITY(1,1) PRIMARY KEY,
    usuario_id INT NOT NULL,
    empleado_id INT NULL,
    servicio_id INT NOT NULL,
    fecha_hora DATETIME NOT NULL,
    nombre_invitado NVARCHAR(100),
    telefono_invitado NVARCHAR(20),
    estado NVARCHAR(20) NOT NULL,
    creado_en DATETIME DEFAULT GETDATE(),
    actualizado_en DATETIME NULL,
    cancelacion_motivo NVARCHAR(255),
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    FOREIGN KEY (servicio_id) REFERENCES servicios(id)
);

GO

-- CRUD USUARIOS
CREATE PROCEDURE CrearUsuario
    @nombre NVARCHAR(100),
    @correo NVARCHAR(100),
    @cedula NVARCHAR(20),
    @contrasena NVARCHAR(100),
    @rol NVARCHAR(20)
AS
BEGIN
    INSERT INTO usuarios (nombre, correo, cedula, contrasena, rol)
    VALUES (@nombre, @correo, @cedula, @contrasena, @rol);
END;
GO

CREATE PROCEDURE ObtenerUsuarioPorId
    @id INT
AS
BEGIN
    SELECT * FROM usuarios WHERE id = @id;
END;
GO

CREATE PROCEDURE ListarUsuarios
AS
BEGIN
    SELECT * FROM usuarios;
END;
GO

CREATE PROCEDURE ActualizarUsuario
    @id INT,
    @nombre NVARCHAR(100),
    @correo NVARCHAR(100),
    @cedula NVARCHAR(20),
    @rol NVARCHAR(20)
AS
BEGIN
    UPDATE usuarios
    SET nombre = @nombre,
        correo = @correo,
        cedula = @cedula,
        rol = @rol,
        actualizado_en = GETDATE()
    WHERE id = @id;
END;
GO

CREATE PROCEDURE EliminarUsuario
    @id INT
AS
BEGIN
    DELETE FROM usuarios WHERE id = @id;
END;
GO

-- CRUD SERVICIOS
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

CREATE PROCEDURE ObtenerServicioPorId
    @id INT
AS
BEGIN
    SELECT * FROM servicios WHERE id = @id;
END;
GO

CREATE PROCEDURE ListarServicios
AS
BEGIN
    SELECT * FROM servicios;
END;
GO

CREATE PROCEDURE ActualizarServicio
    @id INT,
    @nombre NVARCHAR(100),
    @descripcion NVARCHAR(255),
    @precio DECIMAL(10,2)
AS
BEGIN
    UPDATE servicios
    SET nombre = @nombre,
        descripcion = @descripcion,
        precio = @precio,
        actualizado_en = GETDATE()
    WHERE id = @id;
END;
GO

CREATE PROCEDURE EliminarServicio
    @id INT
AS
BEGIN
    DELETE FROM servicios WHERE id = @id;
END;
GO

-- CRUD PRODUCTOS
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

CREATE PROCEDURE ObtenerProductoPorId
    @id INT
AS
BEGIN
    SELECT * FROM productos WHERE id = @id;
END;
GO

CREATE PROCEDURE ListarProductos
AS
BEGIN
    SELECT * FROM productos;
END;
GO

CREATE PROCEDURE ActualizarProducto
    @id INT,
    @nombre NVARCHAR(100),
    @descripcion NVARCHAR(255),
    @precio DECIMAL(10,2),
    @imagen NVARCHAR(255),
    @cantidad_disponible INT
AS
BEGIN
    UPDATE productos
    SET nombre = @nombre,
        descripcion = @descripcion,
        precio = @precio,
        imagen = @imagen,
        cantidad_disponible = @cantidad_disponible,
        actualizado_en = GETDATE()
    WHERE id = @id;
END;
GO

CREATE PROCEDURE EliminarProducto
    @id INT
AS
BEGIN
    DELETE FROM productos WHERE id = @id;
END;
GO

-- CRUD CITAS
CREATE PROCEDURE CrearCita
    @usuario_id INT,
    @servicio_id INT,
    @fecha_hora DATETIME,
    @estado NVARCHAR(20)
AS
BEGIN
    INSERT INTO citas (usuario_id, servicio_id, fecha_hora, estado)
    VALUES (@usuario_id, @servicio_id, @fecha_hora, @estado);
END;
GO

CREATE PROCEDURE ObtenerCitaPorId
    @id INT
AS
BEGIN
    SELECT * FROM citas WHERE id = @id;
END;
GO

CREATE PROCEDURE ListarCitas
AS
BEGIN
    SELECT * FROM citas;
END;
GO

CREATE PROCEDURE ActualizarCita
    @id INT,
    @estado NVARCHAR(20),
    @cancelacion_motivo NVARCHAR(255)
AS
BEGIN
    UPDATE citas
    SET estado = @estado,
        cancelacion_motivo = @cancelacion_motivo,
        actualizado_en = GETDATE()
    WHERE id = @id;
END;
GO

CREATE PROCEDURE EliminarCita
    @id INT
AS
BEGIN
    DELETE FROM citas WHERE id = @id;
END;
GO

CREATE PROCEDURE ObtenerCitasPorUsuario
    @usuario_id INT
AS
BEGIN
    SELECT * FROM citas WHERE usuario_id = @usuario_id;
END;
GO