-- Crear tablas para el sistema de facturas
-- Basado en el diseño proporcionado

-- Tabla principal de facturas
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

-- Tabla de detalles de factura
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

-- Agregar estado 'finalizada' a las citas si no existe
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CHK_citas_estado_extended')
BEGIN
    -- Primero eliminar la restricción existente si existe
    DECLARE @constraint_name NVARCHAR(128)
    SELECT @constraint_name = name 
    FROM sys.check_constraints 
    WHERE parent_object_id = OBJECT_ID('citas') 
      AND definition LIKE '%estado%'
    
    IF @constraint_name IS NOT NULL
    BEGIN
        EXEC('ALTER TABLE citas DROP CONSTRAINT ' + @constraint_name)
    END
    
    -- Agregar la nueva restricción con el estado 'finalizada'
    ALTER TABLE citas ADD CONSTRAINT CHK_citas_estado_extended 
    CHECK (estado IN ('pendiente', 'confirmada', 'rechazada', 'cancelada', 'atendida', 'finalizada'))
END

-- Índices para mejor rendimiento
CREATE INDEX IX_factura_idCita ON factura(idCita);
CREATE INDEX IX_detallefactura_idFact ON detallefactura(idFact);
CREATE INDEX IX_detallefactura_idProducto ON detallefactura(idProducto);
CREATE INDEX IX_detallefactura_idServicio ON detallefactura(idServicio);

PRINT 'Tablas de facturas creadas correctamente';