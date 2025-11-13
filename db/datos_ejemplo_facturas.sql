-- Script para insertar datos de ejemplo en el sistema de facturas
-- Ejecutar después de las migraciones

-- =============================================
-- INSERTAR FACTURAS DE EJEMPLO
-- =============================================

-- Facturas usando stored procedure CrearFactura
DECLARE @factura1_id INT, @numero1 NVARCHAR(50), @fecha1 DATETIME;
DECLARE @factura2_id INT, @numero2 NVARCHAR(50), @fecha2 DATETIME;
DECLARE @factura3_id INT, @numero3 NVARCHAR(50), @fecha3 DATETIME;
DECLARE @factura4_id INT, @numero4 NVARCHAR(50), @fecha4 DATETIME;
DECLARE @factura5_id INT, @numero5 NVARCHAR(50), @fecha5 DATETIME;

-- Factura 1: Usuario María García (ID 2) - Servicios y productos
EXEC CrearFactura @usuario_id = 2;
SELECT TOP 1 @factura1_id = id, @numero1 = numero_factura, @fecha1 = fecha_emision 
FROM facturas ORDER BY id DESC;

-- Factura 2: Usuario Steven (ID 1) - Solo servicios premium
EXEC CrearFactura @usuario_id = 1;
SELECT TOP 1 @factura2_id = id, @numero2 = numero_factura, @fecha2 = fecha_emision 
FROM facturas WHERE id > @factura1_id ORDER BY id DESC;

-- Factura 3: Usuario Juan (ID 3) - Compra de productos
EXEC CrearFactura @usuario_id = 3;
SELECT TOP 1 @factura3_id = id, @numero3 = numero_factura, @fecha3 = fecha_emision 
FROM facturas WHERE id > @factura2_id ORDER BY id DESC;

-- Factura 4: Usuario Steven Venegas (ID 12) - Servicios múltiples
EXEC CrearFactura @usuario_id = 12;
SELECT TOP 1 @factura4_id = id, @numero4 = numero_factura, @fecha4 = fecha_emision 
FROM facturas WHERE id > @factura3_id ORDER BY id DESC;

-- Factura 5: Usuario María García (ID 2) - Factura pagada del día anterior
EXEC CrearFactura @usuario_id = 2;
SELECT TOP 1 @factura5_id = id, @numero5 = numero_factura, @fecha5 = fecha_emision 
FROM facturas WHERE id > @factura4_id ORDER BY id DESC;

-- =============================================
-- AGREGAR ITEMS A LAS FACTURAS
-- =============================================

-- FACTURA 1: María García - Servicio completo con productos
PRINT 'Agregando items a Factura 1 (' + @numero1 + ')';

-- Corte de cabello
EXEC AgregarServicioAFactura @factura_id = @factura1_id, @servicio_id = 1, @cantidad = 1;

-- Manicure
EXEC AgregarServicioAFactura @factura_id = @factura1_id, @servicio_id = 2, @cantidad = 1;

-- Shampoo x2
EXEC AgregarProductoAFactura @factura_id = @factura1_id, @producto_id = 1, @cantidad = 2;

-- Esmalte
EXEC AgregarProductoAFactura @factura_id = @factura1_id, @producto_id = 2, @cantidad = 1;

-- FACTURA 2: Steven - Servicios premium
PRINT 'Agregando items a Factura 2 (' + @numero2 + ')';

-- Alisado
EXEC AgregarServicioAFactura @factura_id = @factura2_id, @servicio_id = 4, @cantidad = 1;

-- Mechas premium
EXEC AgregarServicioAFactura @factura_id = @factura2_id, @servicio_id = 9, @cantidad = 1;

-- Base líquida x2
EXEC AgregarProductoAFactura @factura_id = @factura2_id, @producto_id = 3, @cantidad = 2;

-- FACTURA 3: Juan - Solo productos
PRINT 'Agregando items a Factura 3 (' + @numero3 + ')';

-- Shampoo x3 (compra al por mayor)
EXEC AgregarProductoAFactura @factura_id = @factura3_id, @producto_id = 1, @cantidad = 3;

-- Esmalte x5 (varios colores)
EXEC AgregarProductoAFactura @factura_id = @factura3_id, @producto_id = 2, @cantidad = 5;

-- Base líquida x1
EXEC AgregarProductoAFactura @factura_id = @factura3_id, @producto_id = 3, @cantidad = 1;

-- FACTURA 4: Steven Venegas - Servicios múltiples
PRINT 'Agregando items a Factura 4 (' + @numero4 + ')';

-- Corte de cabello
EXEC AgregarServicioAFactura @factura_id = @factura4_id, @servicio_id = 1, @cantidad = 1;

-- Mechas regulares
EXEC AgregarServicioAFactura @factura_id = @factura4_id, @servicio_id = 7, @cantidad = 1;

-- Shampoo x1
EXEC AgregarProductoAFactura @factura_id = @factura4_id, @producto_id = 1, @cantidad = 1;

-- FACTURA 5: María García - Para marcar como pagada
PRINT 'Agregando items a Factura 5 (' + @numero5 + ')';

-- Manicure
EXEC AgregarServicioAFactura @factura_id = @factura5_id, @servicio_id = 2, @cantidad = 1;

-- Esmalte x2
EXEC AgregarProductoAFactura @factura_id = @factura5_id, @producto_id = 2, @cantidad = 2;

-- =============================================
-- ACTUALIZAR FECHAS Y ESTADOS
-- =============================================

-- Hacer que la factura 5 sea del día anterior y esté pagada
UPDATE facturas 
SET fecha_emision = DATEADD(day, -1, GETDATE()),
    creado_en = DATEADD(day, -1, GETDATE())
WHERE id = @factura5_id;

-- Marcar factura 5 como pagada
EXEC ActualizarFactura @factura_id = @factura5_id, @estado = 'pagada';

-- Hacer que algunas facturas sean de fechas diferentes para testing
UPDATE facturas 
SET fecha_emision = DATEADD(hour, -3, GETDATE()),
    creado_en = DATEADD(hour, -3, GETDATE())
WHERE id = @factura1_id;

UPDATE facturas 
SET fecha_emision = DATEADD(hour, -1, GETDATE()),
    creado_en = DATEADD(hour, -1, GETDATE())
WHERE id = @factura3_id;

-- =============================================
-- VERIFICAR DATOS CREADOS
-- =============================================
PRINT '';
PRINT '=== RESUMEN DE FACTURAS CREADAS ===';

SELECT 
    f.id,
    f.numero_factura,
    u.nombre AS cliente,
    f.fecha_emision,
    f.subtotal,
    f.impuestos,
    f.total,
    f.estado,
    COUNT(df.id) AS num_items
FROM facturas f
INNER JOIN usuarios u ON f.usuario_id = u.id
LEFT JOIN detallefactura df ON f.id = df.factura_id
GROUP BY f.id, f.numero_factura, u.nombre, f.fecha_emision, f.subtotal, f.impuestos, f.total, f.estado
ORDER BY f.id;

PRINT '';
PRINT '=== DETALLE DE ITEMS POR FACTURA ===';

SELECT 
    f.numero_factura,
    df.tipo_item,
    df.descripcion,
    df.cantidad,
    df.precio_unitario,
    df.subtotal
FROM facturas f
INNER JOIN detallefactura df ON f.id = df.factura_id
ORDER BY f.id, df.tipo_item, df.descripcion;

PRINT '';
PRINT '=== MÉTRICAS GENERALES ===';

SELECT 
    COUNT(*) AS total_facturas,
    SUM(CASE WHEN estado = 'pendiente' THEN 1 ELSE 0 END) AS pendientes,
    SUM(CASE WHEN estado = 'pagada' THEN 1 ELSE 0 END) AS pagadas,
    SUM(CASE WHEN estado = 'anulada' THEN 1 ELSE 0 END) AS anuladas,
    SUM(total) AS total_ventas,
    AVG(total) AS promedio_factura
FROM facturas;

PRINT '';
PRINT 'Datos de ejemplo creados exitosamente!';
PRINT 'Puedes probar el frontend en: http://localhost:4200';
PRINT 'Login: admin@admin / admin';
PRINT 'Navegar a: Facturas (Admin)';