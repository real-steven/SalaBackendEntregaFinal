-- Script completo para sistema de facturas con triggers y stored procedures

-- 1. CREAR TABLAS
-- Crear tabla facturas
CREATE TABLE facturas (
    id INT IDENTITY(1,1) PRIMARY KEY,
    cita_id INT NOT NULL,
    numero_factura NVARCHAR(50) NOT NULL UNIQUE,
    fecha_emision DATETIME NOT NULL DEFAULT GETDATE(),
    subtotal DECIMAL(10,2) NOT NULL,
    impuestos DECIMAL(10,2) NOT NULL DEFAULT 0,
    total DECIMAL(10,2) NOT NULL,
    estado NVARCHAR(20) NOT NULL DEFAULT 'pendiente',
    metodo_pago NVARCHAR(50) NULL,
    notas TEXT NULL,
    creado_en DATETIME DEFAULT GETDATE(),
    actualizado_en DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (cita_id) REFERENCES citas(id)
);

-- Crear tabla detalle de factura
CREATE TABLE detallefactura (
    id INT IDENTITY(1,1) PRIMARY KEY,
    factura_id INT NOT NULL,
    tipo_item NVARCHAR(20) NOT NULL,
    item_id INT NOT NULL,
    descripcion NVARCHAR(255) NOT NULL,
    cantidad INT NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    creado_en DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (factura_id) REFERENCES facturas(id) ON DELETE CASCADE
);

-- Índices
CREATE INDEX IX_facturas_cita_id ON facturas(cita_id);
CREATE INDEX IX_facturas_numero ON facturas(numero_factura);
CREATE INDEX IX_facturas_fecha ON facturas(fecha_emision);
CREATE INDEX IX_detallefactura_factura_id ON detallefactura(factura_id);