-- Datos de ejemplo
INSERT INTO usuarios (nombre, correo, cedula, contrasena, rol) VALUES
('Steven', 'steven@email.com', '123456789', 'pass123', 'admin'),
('Maria', 'maria@email.com', '987654321', 'pass456', 'cliente'),
('Juan', 'juan@email.com', '456789123', 'pass789', 'empleado');

INSERT INTO servicios (nombre, descripcion, precio) VALUES
('Corte de cabello', 'Corte profesional', 15.00),
('Manicure', 'Manicure completo', 20.00),
('Maquillaje', 'Maquillaje social', 30.00);

INSERT INTO productos (nombre, descripcion, precio, imagen, cantidad_disponible) VALUES
('Shampoo', 'Shampoo hidratante', 8.50, 'shampoo.png', 50),
('Esmalte', 'Esmalte rojo', 5.00, 'esmalte.png', 100),
('Base', 'Base líquida', 12.00, 'base.png', 30);

-- Consultas para verificar los datos
SELECT TOP 10 * FROM productos;
SELECT TOP 10 * FROM servicios;
SELECT TOP 10 * FROM usuarios;