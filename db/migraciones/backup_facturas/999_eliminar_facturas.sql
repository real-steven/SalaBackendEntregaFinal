-- Script para eliminar completamente el sistema de facturas
-- Ejecutar en orden

-- 1. Eliminar stored procedures relacionados con facturas
DROP PROCEDURE IF EXISTS CrearFactura;
DROP PROCEDURE IF EXISTS ListarFacturas;
DROP PROCEDURE IF EXISTS ObtenerFactura;
DROP PROCEDURE IF EXISTS ActualizarFactura;
DROP PROCEDURE IF EXISTS AgregarProductoAFactura;
DROP PROCEDURE IF EXISTS AgregarServicioAFactura;

-- 2. Eliminar restricciones de claves foráneas
IF EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_detallefactura_factura')
    ALTER TABLE detallefactura DROP CONSTRAINT FK_detallefactura_factura;

IF EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_facturas_usuario')
    ALTER TABLE facturas DROP CONSTRAINT FK_facturas_usuario;

IF EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_facturas_cita')
    ALTER TABLE facturas DROP CONSTRAINT FK_facturas_cita;

-- 3. Eliminar triggers
DROP TRIGGER IF EXISTS tr_facturas_calcular_totales;
DROP TRIGGER IF EXISTS tr_detallefactura_actualizar_factura;

-- 4. Eliminar secuencias
DROP SEQUENCE IF EXISTS seq_numero_factura;

-- 5. Eliminar tablas (orden importante por dependencias)
DROP TABLE IF EXISTS detallefactura;
DROP TABLE IF EXISTS facturas;

-- 6. Eliminar columna factura_id de citas si existe
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('citas') AND name = 'factura_id')
    ALTER TABLE citas DROP COLUMN factura_id;

PRINT 'Sistema de facturas eliminado completamente de la base de datos';